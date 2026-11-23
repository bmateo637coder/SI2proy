"""CRM comercial: oportunidades versionadas y planes de seguimiento asistidos."""
from datetime import datetime, date, timedelta, timezone
from decimal import Decimal
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, ConfigDict
from sqlalchemy import Column, Integer, String, ForeignKey, Numeric, Boolean, JSON
from sqlalchemy.orm import Session
from database.database import Base, get_db
from database import models as m
from auth import require_reader, require_staff, scope_query
from sprint4_ia import clasificar_consulta
from saas import require_ai, today

router = APIRouter(prefix='/api', tags=['Embudo comercial y workflow IA'])
Stage = Literal['Nuevo', 'Contactado', 'Visita', 'Negociacion', 'Ganado', 'Perdido']
STAGES = ['Nuevo', 'Contactado', 'Visita', 'Negociacion', 'Ganado', 'Perdido']


class Opportunity(Base):
    __tablename__ = 'crm_oportunidad'
    id = Column(Integer, primary_key=True)
    id_tenant = Column(Integer, ForeignKey('tenant.id_tenant'), nullable=False, index=True)
    titulo = Column(String(150), nullable=False)
    contacto = Column(String(200), nullable=False)
    notas = Column(String(3000), nullable=False, default='')
    etapa = Column(String(30), nullable=False, default='Nuevo')
    importe = Column(Numeric(14, 2), nullable=False, default=0)
    probabilidad = Column(Integer, nullable=False, default=10)
    proximo_contacto = Column(String(10), nullable=True)
    id_cliente = Column(Integer, ForeignKey('cliente.id_cliente'), nullable=True)
    id_propiedad = Column(Integer, ForeignKey('propiedad.id_propiedad'), nullable=True)
    id_agente = Column(Integer, ForeignKey('agente.id_agente'), nullable=True)
    archivada = Column(Boolean, nullable=False, default=False)
    version = Column(Integer, nullable=False, default=1)
    historial = Column(JSON, nullable=False, default=list)


class Workflow(Base):
    __tablename__ = 'crm_workflow'
    id = Column(Integer, primary_key=True)
    id_tenant = Column(Integer, ForeignKey('tenant.id_tenant'), nullable=False, index=True)
    id_oportunidad = Column(Integer, ForeignKey('crm_oportunidad.id'), nullable=True)
    texto = Column(String(3000), nullable=False)
    categoria = Column(String(30), nullable=False)
    urgencia = Column(String(20), nullable=False)
    modo = Column(String(30), nullable=False)
    justificacion = Column(String(500), nullable=False)
    tareas = Column(JSON, nullable=False)
    historial = Column(JSON, nullable=False, default=list)
    version = Column(Integer, nullable=False, default=1)


class OpportunityIn(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra='forbid')
    titulo: str = Field(min_length=3, max_length=150)
    contacto: str = Field(min_length=3, max_length=200)
    notas: str = Field(default='', max_length=3000)
    etapa: Stage = 'Nuevo'
    importe: Decimal = Field(default=0, ge=0, le=999999999999, max_digits=14, decimal_places=2)
    probabilidad: int = Field(default=10, ge=0, le=100)
    proximo_contacto: date | None = None
    id_cliente: int | None = Field(default=None, gt=0)
    id_propiedad: int | None = Field(default=None, gt=0)
    id_agente: int | None = Field(default=None, gt=0)


class OpportunityEdit(OpportunityIn):
    version: int = Field(ge=1)


class WorkflowIn(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra='forbid')
    texto: str = Field(min_length=5, max_length=3000)
    id_oportunidad: int | None = Field(default=None, gt=0)


class TaskEdit(BaseModel):
    model_config = ConfigDict(extra='forbid')
    version: int = Field(ge=1)
    tarea: int = Field(ge=0, le=9)
    completada: bool


def audit(user, accion):
    return {'fecha': datetime.now(timezone.utc).isoformat(), 'usuario': user.ci, 'accion': accion}


def serialize(row, db):
    result = {c.name: getattr(row, c.name) for c in row.__table__.columns}
    tenant = db.get(m.Tenant, row.id_tenant)
    result['inmobiliaria'] = tenant.nombre if tenant else ''
    if isinstance(row, Opportunity):
        result['importe'] = float(row.importe)
        result['ponderado'] = round(float(row.importe) * row.probabilidad / 100, 2)
    else:
        result['estado'] = 'Completado' if all(t['completada'] for t in row.tareas) else 'Pendiente'
    return result


def get_row(model, ident, db, user, version=None):
    row = scope_query(db.query(model), user, model.id_tenant).filter(model.id == ident).with_for_update().first()
    if not row: raise HTTPException(404, 'Registro no encontrado en esta inmobiliaria.')
    if version is not None and row.version != version:
        raise HTTPException(409, {'mensaje': 'El registro cambió. Revisa la versión del servidor antes de volver a aplicar tu cambio.', 'servidor': serialize(row, db)})
    return row


def references(body, db, user):
    for field, model, pk in [('id_cliente', m.Cliente, m.Cliente.id_cliente), ('id_propiedad', m.Propiedad, m.Propiedad.id_propiedad), ('id_agente', m.Agente, m.Agente.id_agente)]:
        ident = getattr(body, field)
        if ident and not db.query(model).filter(pk == ident, model.id_tenant == user.id_tenant).first():
            raise HTTPException(422, f'{field}: el registro no pertenece a esta inmobiliaria.')


@router.get('/oportunidades/opciones')
def options(db: Session = Depends(get_db), user=Depends(require_reader)):
    result = {'etapas': STAGES}
    for name, model, pk in [('clientes', m.Cliente, 'id_cliente'), ('agentes', m.Agente, 'id_agente'), ('propiedades', m.Propiedad, 'id_propiedad')]:
        result[name] = [{'id': getattr(r, pk), 'nombre': r.titulo if name == 'propiedades' else r.usuario.nombre, 'id_tenant': r.id_tenant}
                        for r in scope_query(db.query(model), user, model.id_tenant).order_by(getattr(model, pk)).all()]
    return result


@router.get('/oportunidades')
def opportunities(db: Session = Depends(get_db), user=Depends(require_reader)):
    return [serialize(r, db) for r in scope_query(db.query(Opportunity), user, Opportunity.id_tenant).filter_by(archivada=False).order_by(Opportunity.id.desc()).all()]


@router.post('/oportunidades')
def create_opportunity(body: OpportunityIn, db: Session = Depends(get_db), user=Depends(require_staff)):
    require_staff(user); references(body, db, user)
    values = body.model_dump(mode='json'); values['importe'] = body.importe
    if body.etapa == 'Ganado': values['probabilidad'] = 100
    if body.etapa == 'Perdido': values['probabilidad'] = 0
    row = Opportunity(**values, id_tenant=user.id_tenant, historial=[audit(user, 'Creación')])
    db.add(row); db.commit(); db.refresh(row)
    return serialize(row, db)


@router.put('/oportunidades/{ident}')
def update_opportunity(ident: int, body: OpportunityEdit, db: Session = Depends(get_db), user=Depends(require_staff)):
    require_staff(user)
    row = get_row(Opportunity, ident, db, user, body.version)
    if row.archivada: raise HTTPException(409, 'La oportunidad está archivada.')
    references(body, db, user)
    previous = row.etapa
    for k, v in body.model_dump(mode='json', exclude={'version'}).items(): setattr(row, k, v)
    row.importe = body.importe
    if row.etapa == 'Ganado': row.probabilidad = 100
    if row.etapa == 'Perdido': row.probabilidad = 0
    row.historial = row.historial + [audit(user, f'{previous} → {row.etapa}' if previous != row.etapa else 'Edición')]
    row.version += 1
    db.commit(); db.refresh(row)
    return serialize(row, db)


@router.delete('/oportunidades/{ident}')
def archive_opportunity(ident: int, version: int, db: Session = Depends(get_db), user=Depends(require_staff)):
    require_staff(user)
    row = get_row(Opportunity, ident, db, user, version)
    row.archivada = True; row.version += 1
    row.historial = row.historial + [audit(user, 'Archivada')]
    db.commit(); db.refresh(row)
    return serialize(row, db)


def plan(body, user):
    classification, mode = clasificar_consulta(body.texto, user)
    category = classification.categoria
    action = {'Visita': 'Coordinar fecha y confirmar la visita', 'Precio': 'Preparar propuesta y revisar presupuesto',
              'Compra': 'Seleccionar inmuebles para compra', 'Alquiler': 'Revisar requisitos y opciones de alquiler',
              'Anticretico': 'Revisar condiciones de anticrético'}.get(category, 'Aclarar necesidades y preferencias')
    days = 0 if classification.urgencia in ('Alta', 'Critica') else 3 if classification.urgencia == 'Baja' else 1
    tasks = [{'titulo': text, 'completada': False, 'vence': (today() + timedelta(days=days + i)).isoformat()}
             for i, text in enumerate(['Contactar al interesado y validar sus datos', action, 'Registrar resultado y siguiente contacto en la oportunidad'])]
    return {'categoria': category, 'urgencia': classification.urgencia, 'justificacion': classification.justificacion,
            'modo': mode, 'tareas': tasks}


@router.get('/workflow-ia')
def workflows(db: Session = Depends(get_db), user=Depends(require_reader)):
    return [serialize(r, db) for r in scope_query(db.query(Workflow), user, Workflow.id_tenant).order_by(Workflow.id.desc()).all()]


@router.post('/workflow-ia')
def create_workflow(body: WorkflowIn, db: Session = Depends(get_db), user=Depends(require_staff)):
    require_staff(user); require_ai(db, user)
    if body.id_oportunidad:
        opportunity = get_row(Opportunity, body.id_oportunidad, db, user)
        if opportunity.archivada: raise HTTPException(422, 'La oportunidad está archivada.')
    row = Workflow(**body.model_dump(), **plan(body, user), id_tenant=user.id_tenant, historial=[audit(user, 'Plan generado; pendiente de revisión humana')])
    db.add(row); db.commit(); db.refresh(row)
    return serialize(row, db)


@router.put('/workflow-ia/{ident}')
def update_task(ident: int, body: TaskEdit, db: Session = Depends(get_db), user=Depends(require_staff)):
    require_staff(user)
    row = get_row(Workflow, ident, db, user, body.version)
    if body.tarea >= len(row.tareas): raise HTTPException(422, 'Tarea inexistente.')
    tasks = [dict(t) for t in row.tareas]; tasks[body.tarea]['completada'] = body.completada
    row.tareas = tasks; row.version += 1
    row.historial = row.historial + [audit(user, f'Tarea {body.tarea + 1}: ' + ('completada' if body.completada else 'reabierta'))]
    db.commit(); db.refresh(row)
    return serialize(row, db)

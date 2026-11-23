"""Fotos de inmuebles persistentes, compartidas por web y Android."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, Response, UploadFile
from sqlalchemy import Column, String, LargeBinary
from sqlalchemy.orm import Session
from database.database import Base, get_db


class FotoInmueble(Base):
    __tablename__ = 'foto_inmueble'
    id = Column(String(36), primary_key=True)
    contenido = Column(LargeBinary, nullable=False)
    mime = Column(String(30), nullable=False)


router = APIRouter(tags=['Fotos de inmuebles'])


def save_photo(file: UploadFile, db: Session):
    data = file.file.read(5 * 1024 * 1024 + 1)
    if len(data) > 5 * 1024 * 1024:
        raise HTTPException(413, 'La foto debe pesar como máximo 5 MB.')
    if data.startswith(b'\xff\xd8\xff'): mime = 'image/jpeg'
    elif data.startswith(b'\x89PNG\r\n\x1a\n'): mime = 'image/png'
    elif data.startswith(b'RIFF') and data[8:12] == b'WEBP': mime = 'image/webp'
    else: raise HTTPException(415, 'Seleccione una imagen JPEG, PNG o WebP.')
    row = FotoInmueble(id=str(uuid.uuid4()), contenido=data, mime=mime)
    db.add(row); db.commit()
    return {'url': '/api/fotos-inmuebles/' + row.id}


@router.get('/api/fotos-inmuebles/{ident}')
def photo(ident: str, db: Session = Depends(get_db)):
    row = db.get(FotoInmueble, ident)
    if not row: raise HTTPException(404, 'Foto no encontrada.')
    return Response(row.contenido, media_type=row.mime, headers={'Cache-Control': 'public, max-age=31536000, immutable', 'X-Content-Type-Options': 'nosniff'})

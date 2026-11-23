"""Expose restrictive relationships as a reviewable conflict before deletion."""
from fastapi import HTTPException
from sqlalchemy import select
from database.database import Base


def protect_history(db, model, ident, label):
    target = model.__table__
    for table in Base.metadata.sorted_tables:
        for fk in table.foreign_keys:
            if fk.column.table is target and (fk.ondelete or '').upper() not in {'CASCADE', 'SET NULL', 'SET DEFAULT'}:
                if db.execute(select(1).select_from(table).where(fk.parent == ident).limit(1)).first():
                    raise HTTPException(409, f'{label} tiene registros asociados. Desvincúlelos antes de eliminar o conserve el historial.')

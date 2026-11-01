"""La agrupación por inmobiliaria la aplica el servidor, no el modelo generativo."""
import json
import pytest
from reportes_generativos import interpret, local_spec


@pytest.mark.parametrize('text', [
    'Cantidad de propiedades por inmobiliaria y estado',
    'Cantidad de inmuebles por empresa y estado',
])
def test_company_inventory_without_provider(text):
    assert local_spec(text).tipo == 'cartera_estado'


def test_provider_knows_company_grouping_is_automatic(monkeypatch):
    monkeypatch.setenv('GEMINI_API_KEY', 'test-only')

    def generate(prompt, **kwargs):
        assert 'automáticamente' in prompt
        assert 'inmobiliaria o empresa y estado' in prompt
        assert 'no necesita campos adicionales' in prompt
        return json.dumps({'tipo': 'cartera_estado'})

    monkeypatch.setattr('reportes_generativos.generate_text', generate)
    spec, provider = interpret('Cantidad de propiedades por inmobiliaria y estado')
    assert spec.tipo == 'cartera_estado'
    assert provider == 'gemini'

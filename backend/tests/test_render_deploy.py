"""Controles del despliegue: destino, secretos y version publicada."""
import contextlib
import io
import json
import os
import unittest
from unittest.mock import patch

from scripts import deploy_render as deploy


URL = "https://raices-backend-n1yy.onrender.com"


class RenderDeploymentTests(unittest.TestCase):
    def service(self, repo=deploy.EXPECTED_REPO):
        return {"id": "srv-test", "type": "web_service", "repo": repo,
                "serviceDetails": {"url": URL}}

    def test_rejects_matching_url_owned_by_another_repository(self):
        with patch.object(deploy, "api", return_value=[{"service": self.service("https://github.com/other/repo")}]), self.assertRaises(SystemExit):
            deploy.discover(URL)

    def test_rejects_ambiguous_destination(self):
        with patch.object(deploy, "api", return_value=[{"service": self.service()}, {"service": self.service()}]), self.assertRaises(SystemExit):
            deploy.discover(URL)

    def test_inspection_exposes_variable_names_without_values(self):
        variables = [{"envVar": {"key": "DATABASE_URL", "value": "postgresql://private:password@host/db"}},
                     {"envVar": {"key": "JWT_SECRET_KEY", "value": "private-signing-key"}}]
        output = io.StringIO()
        with patch.object(deploy, "api", side_effect=[variables, []]), contextlib.redirect_stdout(output):
            deploy.inspect_service(self.service())
        self.assertIn("DATABASE_URL", output.getvalue())
        self.assertNotIn("password", output.getvalue())
        self.assertNotIn("private-signing-key", output.getvalue())

    def test_does_not_accept_a_different_deployed_commit(self):
        response = io.BytesIO(json.dumps({"version": "2.0.0", "commit": "old-commit",
            "features": ["saas", "offline", "analitica"]}).encode())
        with patch.object(deploy, "urlopen", return_value=response), self.assertRaises(SystemExit):
            deploy.verify_health(URL, commit="new-commit", attempts=1)

    def test_redacts_render_token_and_database_connection(self):
        with patch.dict(os.environ, {"RENDER_API_KEY": "rnd_secret-key"}):
            output = deploy.safe("rnd_secret-key postgresql://user:password@host/db")
        self.assertNotIn("secret-key", output)
        self.assertNotIn("password", output)


if __name__ == "__main__":
    unittest.main()

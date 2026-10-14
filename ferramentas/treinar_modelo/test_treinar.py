"""Testes das partes do treinar.py que não precisam do TensorFlow.

Rodar a partir da raiz do repositório (com o Python do requirements.txt ou
qualquer Python 3.10+, já que nada aqui importa o Model Maker):

    python -m unittest discover -s ferramentas/treinar_modelo -p "test_*.py"
"""

from __future__ import annotations

import argparse
import contextlib
import io
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import treinar  # noqa: E402


def _calado(funcao, *args, **kwargs):
    """Roda sem sujar a saída do teste com os avisos do script."""
    with contextlib.redirect_stdout(io.StringIO()) as saida:
        resultado = funcao(*args, **kwargs)
    return resultado, saida.getvalue()


class ConferirTest(unittest.TestCase):
    def test_sem_a_pasta_outros_o_treino_e_recusado(self):
        # Softmax só com duas fases: qualquer foto (até a nota fiscal) sai
        # com 50% ou mais numa delas, e o app preenche a fase errada.
        ok, saida = _calado(treinar.conferir, {"fundacao": 40, "estrutura": 40})
        self.assertFalse(ok)
        self.assertIn("outros", saida)

    def test_com_a_pasta_outros_o_treino_segue(self):
        ok, _ = _calado(
            treinar.conferir, {"fundacao": 40, "estrutura": 40, "outros": 40})
        self.assertTrue(ok)

    def test_fases_sem_fotos_sao_lembradas_para_ir_em_outros(self):
        _, saida = _calado(
            treinar.conferir, {"fundacao": 40, "estrutura": 40, "outros": 40})
        self.assertIn("pintura", saida)


def _foto(caminho: Path, semente: int) -> None:
    """Arquivo com cabeçalho de JPEG; o conteúdo muda com a semente, para
    não ser descartado como foto repetida."""
    caminho.parent.mkdir(parents=True, exist_ok=True)
    caminho.write_bytes(b"\xff\xd8\xff\xe0" + semente.to_bytes(4, "big") * 8)


class MontarDatasetTest(unittest.TestCase):
    def test_zip_com_a_pasta_fotos_dentro_e_aberto_uma_pasta_abaixo(self):
        # "Compactar" no Windows ou no macOS põe a raiz fotos/ dentro do zip:
        # o unzip -d /content/fotos gera /content/fotos/fotos/<fase>/. O
        # macOS ainda junta a pasta __MACOSX ao lado.
        with tempfile.TemporaryDirectory() as pasta:
            origem = Path(pasta) / "content_fotos"
            n = 0
            for fase in ("fundacao", "estrutura", "outros"):
                for _ in range(3):
                    n += 1
                    _foto(origem / "fotos" / fase / f"IMG_{n}.jpg", n)
            _foto(origem / "__MACOSX" / "fotos" / "fundacao" / "._IMG_1.jpg", 99)

            contagem, _ = _calado(treinar.montar_dataset, origem,
                                  Path(pasta) / "dataset")[0]

            self.assertEqual(contagem, {"estrutura": 3, "fundacao": 3, "outros": 3})


    def test_so_entra_arquivo_que_o_model_maker_decodifica(self):
        # O Model Maker só decodifica JPEG, PNG e GIF; BMP, o "._" do macOS
        # e a foto corrompida passavam no --verificar e derrubavam o treino
        # no meio.
        with tempfile.TemporaryDirectory() as pasta:
            origem = Path(pasta) / "fotos"
            _foto(origem / "fundacao" / "boa.jpg", 1)
            png = origem / "fundacao" / "boa.png"
            png.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00" * 16)
            gif = origem / "fundacao" / "boa.gif"
            gif.write_bytes(b"GIF89a" + b"\x00" * 16)
            (origem / "fundacao" / "foto.bmp").write_bytes(b"BM" + b"\x00" * 30)
            (origem / "fundacao" / "._boa.jpg").write_bytes(
                b"\x00\x05\x16\x07" + b"\x00" * 30)
            (origem / "fundacao" / "cortada.jpg").write_bytes(b"")

            (contagem, _), saida = _calado(
                treinar.montar_dataset, origem, Path(pasta) / "dataset")

            self.assertEqual(contagem, {"fundacao": 3})
            self.assertIn("BMP", saida)


class _ModelMakerFalso:
    """O pedaço do mediapipe-model-maker que o treinar() usa, sem
    TensorFlow nem download do TF Hub. Guarda o que havia no export_dir no
    momento do create(): é dali que o Model Maker retoma checkpoint."""

    def __init__(self):
        self.no_create: list[str] = []
        falso = self

        class Dataset:
            size = 10

            @staticmethod
            def from_folder(_pasta):
                return Dataset()

            def split(self, _fracao):
                return Dataset(), Dataset()

        class HParams:
            def __init__(self, **kwargs):
                self.__dict__.update(kwargs)

        class ImageClassifierOptions:
            def __init__(self, supported_model, hparams):
                self.hparams = hparams

        class Modelo:
            def __init__(self, hparams):
                self.hparams = hparams

            def evaluate(self, _dados):
                return [0.5, 0.8]

            def export_model(self, nome, quantization_config=None):
                destino = Path(self.hparams.export_dir)
                destino.mkdir(parents=True, exist_ok=True)
                (destino / nome).write_bytes(b"modelo novo")
                (destino / "metadata.json").write_text("{}")

            def export_labels(self, pasta):
                (Path(pasta) / "labels.txt").write_text("estrutura\nfundacao\n")

        class ImageClassifier:
            @staticmethod
            def create(train_data, validation_data, options):
                pasta = Path(options.hparams.export_dir)
                falso.no_create = sorted(
                    str(f.relative_to(pasta)) for f in pasta.rglob("*")
                ) if pasta.exists() else []
                return Modelo(options.hparams)

        self.image_classifier = types.SimpleNamespace(
            Dataset=Dataset,
            HParams=HParams,
            ImageClassifierOptions=ImageClassifierOptions,
            SupportedModels=types.SimpleNamespace(EFFICIENTNET_LITE0="lite0"),
            ImageClassifier=ImageClassifier,
        )
        self.quantization = types.SimpleNamespace(
            QuantizationConfig=types.SimpleNamespace(for_dynamic=lambda: None))

    def modulos(self):
        raiz = types.ModuleType("mediapipe_model_maker")
        raiz.image_classifier = self.image_classifier
        raiz.quantization = self.quantization
        return {
            "mediapipe_model_maker": raiz,
            # O treinar() fixa a semente do TensorFlow se ele existir.
            "tensorflow": types.SimpleNamespace(
                random=types.SimpleNamespace(set_seed=lambda _s: None)),
        }


class TreinarTest(unittest.TestCase):
    def _treinar(self, saida: Path) -> _ModelMakerFalso:
        falso = _ModelMakerFalso()
        args = argparse.Namespace(
            semente=42, fracao_teste=0.1, fracao_validacao=0.15, saida=str(saida),
            epocas=1, lote=4, taxa=0.001, ajuste_fino=False,
            modelo="efficientnet_lite0", quantizar=False)
        with mock.patch.dict(sys.modules, falso.modulos()):
            _calado(treinar.treinar, args, saida.parent / "dataset",
                    {"estrutura": 12, "fundacao": 12}, None)
        return falso

    def test_retreinar_no_mesmo_saida_nao_retoma_o_treino_anterior(self):
        # O Model Maker retoma o último checkpoint que achar no export_dir:
        # com outro número de classes o treino quebra, com as mesmas ele
        # parte em silêncio dos pesos do anterior.
        with tempfile.TemporaryDirectory() as pasta:
            saida = Path(pasta) / "saida"
            checkpoint = saida / "checkpoint" / "model-0003"
            checkpoint.mkdir(parents=True)
            (checkpoint / "variables.index").write_bytes(b"treino anterior")

            falso = self._treinar(saida)

            self.assertEqual(falso.no_create, [])
            self.assertEqual((saida / treinar.NOME_DO_ARQUIVO).read_bytes(),
                             b"modelo novo")
            self.assertTrue((saida / "labels.txt").exists())


if __name__ == "__main__":
    unittest.main()

"""Offline regression checks for the directly openable station preview."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
PREVIEW_SCENE = ROOT / "scenes/station_preview.tscn"
PREVIEW_SCRIPT = ROOT / "scripts/editor/station_preview.gd"
BUILDER = ROOT / "scripts/station_builder.gd"
HUD = ROOT / "scripts/ui/game_hud.gd"
INTERACTABLE = ROOT / "scripts/interactable.gd"


class EditorPreviewTests(unittest.TestCase):
    def test_preview_scene_and_tool_script_are_present_and_connected(self):
        self.assertTrue(PREVIEW_SCENE.is_file())
        self.assertTrue(PREVIEW_SCRIPT.is_file())
        scene = PREVIEW_SCENE.read_text()
        self.assertIn('path="res://scripts/editor/station_preview.gd"', scene)
        self.assertIn('name="StationPreview" type="Node3D"', scene)

    def test_preview_runs_the_production_builder_in_editor_and_at_runtime(self):
        preview = PREVIEW_SCRIPT.read_text()
        builder = BUILDER.read_text()
        interactable = INTERACTABLE.read_text()
        self.assertIn("@tool", preview)
        self.assertIn('@tool', builder.splitlines()[0])
        self.assertIn('@tool', interactable.splitlines()[0])
        self.assertIn('preload("res://scripts/station_builder.gd")', preview)
        self.assertIn("StationBuilder.new().build(self)", preview)
        self.assertIn('const STATION_ROOT_NAME := "NirvaHalt"', preview)
        self.assertIn('const PREVIEW_CAMERA_NAME := "PreviewCamera"', preview)
        self.assertIn("camera.current = true", preview)

    def test_preview_does_not_replace_the_gameplay_entry_scene(self):
        project = (ROOT / "project.godot").read_text()
        main_scene = (ROOT / "scenes/main.tscn").read_text()
        self.assertIn('run/main_scene="res://scenes/main.tscn"', project)
        self.assertIn('path="res://scripts/game.gd"', main_scene)

    def test_builtin_name_shadowing_warnings_are_fixed(self):
        builder = BUILDER.read_text()
        hud = HUD.read_text()
        self.assertIn("var sign_label := Label3D.new()", builder)
        self.assertNotRegex(builder, r"(?m)^\s*var\s+sign\s*:=")
        self.assertIn("func grime_texture(texture_seed: int, tiled: bool)", builder)
        self.assertNotRegex(builder, r"func\s+grime_texture\s*\(\s*seed\b")
        self.assertIn("var overlay_rect := ColorRect.new()", hud)
        self.assertNotRegex(hud, r"(?m)^\s*var\s+layer\s*:=")


if __name__ == "__main__":
    unittest.main()

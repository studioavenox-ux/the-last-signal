"""Offline structural checks; they cannot prove Godot executes or a player can finish."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ProjectSmokeTests(unittest.TestCase):
    def test_all_res_paths_resolve(self):
        for path in [ROOT / 'project.godot', *ROOT.glob('scenes/*.tscn'), *ROOT.rglob('*.gd')]:
            for ref in re.findall(r'res://([\w./-]+)', path.read_text()):
                self.assertTrue((ROOT / ref).is_file(), f'{path}: missing res://{ref}')

    def test_game_world_keys_exist_in_builder(self):
        game = (ROOT / 'scripts/game.gd').read_text()
        builder = (ROOT / 'scripts/station_builder.gd').read_text()
        used = set(re.findall(r'world\["([^"]+)"\]', game))
        returned = builder.split('return {', 1)[1].split('\n\t}', 1)[0]
        provided = set(re.findall(r'"([^"]+)":', returned))
        self.assertEqual(set(), used - provided)

    def test_connected_ui_signals_and_audio_hooks_exist(self):
        game = (ROOT / 'scripts/game.gd').read_text()
        hud = (ROOT / 'scripts/ui/game_hud.gd').read_text()
        audio = (ROOT / 'scripts/ambient_audio.gd').read_text()
        connected = set(re.findall(r'ui\.([a-z_]+)\.connect\(', game))
        declared = set(re.findall(r'(?m)^signal ([a-z_]+)', hud))
        self.assertFalse(connected - declared)
        for name in ['footstep', 'signal_chirp', 'set_volume']:
            self.assertIn(f'func {name}(', audio)

    def test_main_scene_mobile_and_inputs(self):
        cfg = (ROOT / 'project.godot').read_text()
        self.assertIn('run/main_scene="res://scenes/main.tscn"', cfg)
        self.assertIn('renderer/rendering_method.mobile="gl_compatibility"', cfg)
        self.assertIn('window/handheld/orientation=0', cfg)
        for action in ['move_forward', 'move_back', 'move_left', 'move_right',
                       'interact', 'pause_game', 'journal']:
            self.assertRegex(cfg, rf'(?m)^{action}=')

    def test_all_four_chapters_and_clues(self):
        script = (ROOT / 'scripts/game.gd').read_text()
        story = (ROOT / 'scripts/story_text.gd').read_text()
        ui = (ROOT / 'scripts/ui/game_hud.gd').read_text()
        for flag in ['log_read', 'timetable_read', 'feed_seen', 'transcript_read',
                     'memo_read', 'puzzle_solved', 'list_read', 'door_open',
                     'call_read', 'override_cut']:
            self.assertIn(flag, script)
        self.assertIn('const ORDER := ["3", "1", "2"]', script)
        self.assertIn('BREAKER TRIPPED', script)
        self.assertIn('await get_tree().create_timer(6.0).timeout', script)
        for passage in ['INTRO', 'LOGBOOK', 'FEED', 'TRANSCRIPT', 'MEMO',
                        'PASSENGERS', 'CALL', 'ENDING']:
            self.assertRegex(story, rf'(?m)^const {passage} :=')
        self.assertIn('AARAV SEN', story)
        self.assertIn('ROHAN SEN', story)
        self.assertIn('func journal_text()', script)
        self.assertIn('func show_settings(', ui)
        self.assertIn('RichTextLabel.new()', ui)

    def test_gateway_cannot_be_bypassed_in_map(self):
        builder = (ROOT / 'scripts/station_builder.gd').read_text()
        self.assertIn('Vector3(-5.575, 1.8, 0), Vector3(8.85, 3.6, 0.35)', builder)
        self.assertIn('Vector3(5.575, 1.8, 0), Vector3(8.85, 3.6, 0.35)', builder)
        self.assertIn('"Platform Three gate"', builder)
        self.assertIn('"override"', builder)
        self.assertIn('"timetable"', builder)
        self.assertIn('"transcript"', builder)
        self.assertIn('"Track bed", Vector3(8, -0.15, -6.5)', builder)


if __name__ == '__main__':
    unittest.main()

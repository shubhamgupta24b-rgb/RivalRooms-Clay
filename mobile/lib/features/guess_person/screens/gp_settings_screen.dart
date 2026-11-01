import 'package:flutter/material.dart';
import '../logic/gp_settings.dart';
import '../widgets/gp_theme.dart';

/// Returns the edited settings on DONE; system back keeps the old ones.
class GpSettingsScreen extends StatefulWidget {
  final GpSettings initial;
  const GpSettingsScreen({super.key, required this.initial});
  @override
  State<GpSettingsScreen> createState() => _GpSettingsScreenState();
}

class _GpSettingsScreenState extends State<GpSettingsScreen> {
  late GpSettings s = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CoralBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('SETTINGS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 24),
                      _Choice<int>(
                        title: 'PLAYERS',
                        options: GpSettings.playerOptions,
                        label: (v) => '$v',
                        value: s.playerCount,
                        onChanged: (v) =>
                            setState(() => s = s.copyWith(playerCount: v)),
                      ),
                      _Choice<int>(
                        title: 'ROUNDS',
                        options: GpSettings.roundOptions,
                        label: (v) => '$v',
                        value: s.rounds,
                        onChanged: (v) =>
                            setState(() => s = s.copyWith(rounds: v)),
                      ),
                      _Choice<int>(
                        title: 'PEOPLE ON THE BOARD',
                        options: GpSettings.peopleOptions,
                        label: (v) => '$v',
                        value: s.peopleCount,
                        onChanged: (v) =>
                            setState(() => s = s.copyWith(peopleCount: v)),
                      ),
                      _Choice<int>(
                        title: 'TIMER',
                        options: GpSettings.timerOptions,
                        label: (v) => v == 0 ? 'OFF' : '${v}s',
                        value: s.timerSeconds,
                        onChanged: (v) =>
                            setState(() => s = s.copyWith(timerSeconds: v)),
                      ),
                      _Choice<bool>(
                        title: 'ELIMINATION',
                        options: const [false, true],
                        label: (v) => v ? 'AUTO' : 'MANUAL',
                        value: s.autoEliminate,
                        onChanged: (v) =>
                            setState(() => s = s.copyWith(autoEliminate: v)),
                      ),
                      _Choice<bool>(
                        title: 'SOUND & VIBRATION',
                        options: const [true, false],
                        label: (v) => v ? 'ON' : 'OFF',
                        value: s.sound,
                        onChanged: (v) =>
                            setState(() => s = s.copyWith(sound: v)),
                      ),
                      const SizedBox(height: 12),
                      GpButton('DONE',
                          icon: Icons.check_rounded,
                          onPressed: () => Navigator.pop(context, s)),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Choice<T> extends StatelessWidget {
  final String title;
  final List<T> options;
  final String Function(T) label;
  final T value;
  final ValueChanged<T> onChanged;
  const _Choice(
      {required this.title,
      required this.options,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Row(children: [
          for (final o in options)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Semantics(
                  selected: o == value,
                  button: true,
                  child: Material(
                    color: o == value ? GpColors.accent : GpCoral.panel,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onChanged(o),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        alignment: Alignment.center,
                        child: Text(
                          o == value ? '✓ ${label(o)}' : label(o),
                          style: TextStyle(
                              color: o == value ? GpColors.ink : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

// lib/features/shared/ui/srm_ui.dart
// Building blocks of the web app's look, shared by every screen: the black
// hero banner with an illustration, white panels, black course-code pills,
// pastel stat cards, rounded progress bars and the stale-data notice.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/services/session_sync_orchestrator.dart';
import '../cached_data_providers.dart';

/// The black banner each web page opens with: a Space Grotesk title, a line
/// of text and an illustration on the right.
class HeroBanner extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final String illustration;

  /// Optional action under the text, such as a pill button.
  final Widget? action;

  const HeroBanner({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    required this.illustration,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 170),
      decoration: BoxDecoration(
        color: c.hero,
        borderRadius: BorderRadius.circular(SrmRadii.panel),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: 12,
            top: 16,
            bottom: 16,
            width: 130,
            child: Opacity(
              opacity: 0.9,
              child: SvgPicture.asset(
                illustration,
                fit: BoxFit.contain,
                alignment: Alignment.centerRight,
                excludeFromSemantics: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 150, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!,
                    style: TextStyle(
                      color: c.onHero.withAlpha(178),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: SrmFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                    height: 1.1,
                    letterSpacing: -0.6,
                    color: c.onHero,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: c.onHero.withAlpha(166),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 18),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A pill button for use on a [HeroBanner]: terracotta like the web's
/// "View Timetable", or white like its "Download".
class HeroPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool light;

  const HeroPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = light ? Colors.white : SrmPalette.terracotta;
    final fg = light ? SrmPalette.ink : Colors.white;
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (light ? SrmPalette.ink : Colors.white).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 15, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A white rounded panel (`bg-white rounded-[32px] border`).
class SrmPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;

  const SrmPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.radius = SrmRadii.panel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: color == null ? BorderSide(color: c.border) : BorderSide.none,
    );
    return Material(
      color: color ?? c.card,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A section heading in Space Grotesk, with an optional trailing widget.
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final double size;

  const SectionTitle(this.title, {super.key, this.trailing, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: SrmFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: size,
              letterSpacing: -0.4,
              color: c.text,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// A round icon button like the web's arrow links (`w-8 h-8 rounded-full`).
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final Color? background;
  final Color? foreground;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: background ?? c.track,
        foregroundColor: foreground ?? c.text,
        minimumSize: const Size(44, 44),
      ),
      icon: Icon(icon, size: 18),
    );
  }
}

/// A course code in a small black mono pill.
class CodePill extends StatelessWidget {
  final String code;
  const CodePill(this.code, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.hero,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        code.toUpperCase(),
        style: TextStyle(
          fontFamily: SrmFonts.mono,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.6,
          color: c.onHero,
        ),
      ),
    );
  }
}

/// A small rounded label (`text-[11px] font-bold px-3 py-1 rounded-full`).
class SoftPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const SoftPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// A pastel summary card (`bg-mint rounded-[24px] p-6`) with a big number.
class PastelStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final String? caption;
  final IconData? icon;
  final Color color;

  /// Whether the card is dark enough for white text (terracotta).
  final bool onDark;

  const PastelStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.suffix,
    this.caption,
    this.icon,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : SrmPalette.ink;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(SrmRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ),
              if (icon != null)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: fg),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontFamily: SrmFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 32,
                  height: 1,
                  color: fg,
                ),
              ),
              if (suffix != null)
                TextSpan(
                  text: suffix,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: fg.withAlpha(190),
                  ),
                ),
            ]),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: TextStyle(fontSize: 12, color: fg.withAlpha(178)),
            ),
          ],
        ],
      ),
    );
  }
}

/// A thick rounded bar (`h-3 rounded-full bg-slate-100`).
class SrmProgressBar extends StatelessWidget {
  /// From 0 to 1.
  final double value;
  final Color color;
  final double height;

  const SrmProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        color: color,
        backgroundColor: c.track,
      ),
    );
  }
}

/// Bar colour for an attendance percentage, as on the web: mint when safe,
/// beige when close, terracotta when short.
Color attendanceBarColor(double pct) => pct >= 75
    ? SrmPalette.mint
    : pct >= 50
        ? SrmPalette.beige
        : SrmPalette.terracotta;

/// An uppercase label (`text-[10px] font-bold uppercase tracking-wider`).
class EyebrowLabel extends StatelessWidget {
  final String text;
  const EyebrowLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: SrmColors.of(context).faint,
      ),
    );
  }
}

/// An empty state inside a white panel: an illustration and two lines.
class EmptyPanel extends StatelessWidget {
  final String illustration;
  final String title;
  final String? message;

  const EmptyPanel({
    super.key,
    required this.illustration,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    return SrmPanel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          SvgPicture.asset(illustration,
              height: 120, excludeFromSemantics: true),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: c.text,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.muted, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

/// Says when the data on a screen could not be refreshed, from the last
/// recorded outcome of [sections]. Shows nothing while they are up to date.
class SyncSectionNotice extends ConsumerWidget {
  final List<SyncSection> sections;

  /// What the data is called, such as "attendance".
  final String what;

  const SyncSectionNotice({
    super.key,
    required this.sections,
    required this.what,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).valueOrNull ?? const {};
    final failed = [
      for (final s in sections)
        if (status[s]?.lastError case final String e when e.isNotEmpty)
          (status[s]!, e),
    ];
    if (failed.isEmpty) return const SizedBox.shrink();

    final (row, error) = failed.first;
    final success = row.lastSuccessAt;
    final since = success == null
        ? 'It has not loaded yet.'
        : 'Showing what was saved ${_ago(DateTime.fromMillisecondsSinceEpoch(success))}.';
    final c = SrmColors.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.warn.withAlpha(24),
        borderRadius: BorderRadius.circular(SrmRadii.card),
        border: Border.all(color: c.warn.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.circleAlert, size: 18, color: c.warn),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text:
                      "${what[0].toUpperCase()}${what.substring(1)} didn't refresh. ",
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: '$error $since'),
              ]),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.text,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

/// A compact page title for the inner tabs: Space Grotesk title, one muted
/// line under it, and the page's actions on the right.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: SrmFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 28,
                      height: 1.1,
                      letterSpacing: -0.6,
                      color: c.text,
                    ),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: 8), a],
        ],
      ),
    );
  }
}

/// A small pill action for a [PageHeader], such as "Share".
class HeaderAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Black (primary) or outlined.
  final bool filled;

  const HeaderAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    final fg = filled ? c.onHero : c.text;
    return Material(
      color: filled ? c.hero : c.card,
      shape: StadiumBorder(
          side: filled ? BorderSide.none : BorderSide(color: c.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A two-or-more option pill switch on a light track (Odd/Even semester).
class PillToggle<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  const PillToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, label) in options)
            Semantics(
              button: true,
              selected: v == value,
              child: GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minHeight: 38),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: v == value ? c.hero : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: v == value ? c.onHero : c.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Course colours, as soft pastels that keep dark text readable; index
/// courses in timetable order so a course keeps its colour everywhere.
const courseColors = [
  SrmPalette.mint,
  SrmPalette.lavender,
  SrmPalette.beige,
  Color(0xFFF4CDBE), // soft terracotta
  Color(0xFFCFE0EE), // soft blue
  Color(0xFFEFE3B0), // soft yellow
];

/// The colour for the course at [index] in the timetable.
Color courseColorAt(int index) => courseColors[index % courseColors.length];

/// Fades and slides [children] in one after another when a screen first
/// opens, like the web app's entrance animation. Does nothing when the
/// system asks for reduced motion.
List<Widget> staggeredEntrance(BuildContext context, List<Widget> children) {
  if (MediaQuery.disableAnimationsOf(context)) return children;
  return [
    for (final (i, w) in children.indexed)
      w
          .animate(delay: Duration(milliseconds: 40 * i.clamp(0, 8)))
          .fadeIn(duration: 320.ms, curve: Curves.easeOut)
          .slideY(begin: 0.04, end: 0, duration: 320.ms, curve: Curves.easeOut),
  ];
}

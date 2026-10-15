part of 'provider_account_screen.dart';

String _readable(Object? value) => value is String && value.trim().isNotEmpty
    ? value
          .toLowerCase()
          .split('_')
          .where((w) => w.isNotEmpty)
          .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ')
    : 'Not available';
Widget _asset(String name, double size) =>
    SvgPicture.asset('assets/profile/$name.svg', width: size, height: size);

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({
    required this.name,
    required this.photo,
    required this.rating,
    required this.reviews,
    required this.verified,
    required this.verification,
    this.onEdit,
  });
  final String name;
  final Object? photo, rating, reviews, verification;
  final bool verified;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final uri = photo is String ? Uri.tryParse(photo as String) : null;
    final hasPhoto =
        uri != null &&
        ['https', 'http'].contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
    final edit = _EditAction(onTap: onEdit, full: true);
    final large = MediaQuery.textScalerOf(context).scale(12) > 15.6;
    final identity = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipOval(
              child: SizedBox(
                width: 87,
                height: 87,
                child: hasPhoto
                    ? Image.network(
                        photo as String,
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, s) => const _Avatar(),
                      )
                    : const _Avatar(),
              ),
            ),
            if (verified)
              Positioned(
                right: -1,
                bottom: 3,
                child: ExcludeSemantics(
                  child: Container(
                    width: 23,
                    height: 23,
                    decoration: BoxDecoration(
                      color: homeTeal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                        child: _asset('imgVerificationBadge', 13),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 23),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _asset('imgRatingStar', 15),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text.rich(
                        rating is num && reviews is num
                            ? TextSpan(
                                children: [
                                  TextSpan(
                                    text: (rating as num).toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: _ink,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  TextSpan(text: ' ($reviews reviews)'),
                                ],
                              )
                            : const TextSpan(text: 'No rating available'),
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4FBF8),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (verified) ...[
                        _asset('imgVerificationBadge', 13),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          verified
                              ? 'Profile Verified'
                              : _readable(verification),
                          style: const TextStyle(
                            fontSize: 8.8,
                            color: homeTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!large) ...[const SizedBox(width: 5), edit],
      ],
    );
    return large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [identity, const SizedBox(height: 8), edit],
          )
        : identity;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFEAF9F5),
    child: Icon(Icons.person_outline, color: homeTeal, size: 40),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

class _EditAction extends StatelessWidget {
  const _EditAction({this.onTap, this.full = false, this.label});
  final VoidCallback? onTap;
  final bool full;
  final String? label;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    excludeSemantics: true,
    label: label ?? (full ? 'Edit Profile' : 'Edit'),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(full ? 12 : 99),
      child: SizedBox(
        width: full ? 92.5 : 41,
        height: full ? 31 : 44,
        child: Center(
          child: Container(
            constraints: BoxConstraints(minHeight: full ? 31 : 14),
            padding: EdgeInsets.symmetric(
              horizontal: full ? 8 : 5,
              vertical: full ? 7 : 2,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE1FAF7),
              borderRadius: BorderRadius.circular(full ? 12 : 99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _asset('imgIconFeathericonsEdit', full ? 11 : 8),
                SizedBox(width: full ? 4 : 3),
                Flexible(
                  child: Text(
                    full ? 'Edit Profile' : 'Edit',
                    style: TextStyle(
                      color: onTap == null ? _muted : homeTeal,
                      fontSize: full ? 10.5 : 6,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.asset,
    required this.value,
    required this.label,
    required this.caption,
    required this.color,
  });
  final String asset, value, label, caption;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 70),
    padding: const EdgeInsets.fromLTRB(10, 10, 1, 8),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: LayoutBuilder(
      builder: (context, c) {
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              style: TextStyle(
                fontSize: label == 'Rating' ? 8.5 : 9.4,
                color: _muted,
              ),
            ),
          ],
        );
        final icon = Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: label == 'Services'
                ? const Color(0xFFD9FCF6)
                : label == 'Bookings'
                ? const Color(0xFFEFE5FF)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(child: _asset(asset, label == 'Rating' ? 39 : 20)),
        );
        return c.maxWidth >= 95 &&
                MediaQuery.textScalerOf(context).scale(12) <= 15.6
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icon,
                  const SizedBox(width: 14),
                  Expanded(child: text),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [icon, const SizedBox(height: 6), text],
              );
      },
    ),
  );
}

class _ProfileSection extends StatefulWidget {
  const _ProfileSection({
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.body,
    this.expandedSubtitle,
    this.onEdit,
  });
  final String asset, title, subtitle;
  final String? expandedSubtitle;
  final Widget Function() body;
  final VoidCallback? onEdit;
  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE7EAF0), width: .6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => expanded = !expanded),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 39,
                              height: 38,
                              child: Center(child: _asset(widget.asset, 20)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    expanded
                                        ? widget.expandedSubtitle ??
                                              widget.subtitle
                                        : widget.subtitle,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: _muted,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (expanded)
                  _EditAction(
                    onTap: widget.onEdit,
                    label: 'Edit ${widget.title}',
                  ),
                Semantics(
                  expanded: expanded,
                  button: true,
                  label: '${expanded ? 'Collapse' : 'Expand'} ${widget.title}',
                  child: InkWell(
                    onTap: () => setState(() => expanded = !expanded),
                    child: SizedBox(
                      width: 36,
                      height: 48,
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: expanded ? 2 : 0,
                          child: _asset('imgOpenSetting', 18),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 10,
                    height: 1.15,
                    color: _ink,
                    letterSpacing: 0,
                  ),
                  child: widget.body(),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE8ECF3), width: .5),
      borderRadius: BorderRadius.circular(8),
    ),
    child: child,
  );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.label, required this.onRetry});
  final String label;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  );
}

class _SupportTile extends StatelessWidget {
  const _SupportTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: Color(0xFFE7EAF0), width: .6),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines:
                          MediaQuery.textScalerOf(context).scale(12) <= 15.6
                          ? 1
                          : null,
                      overflow:
                          MediaQuery.textScalerOf(context).scale(12) <= 15.6
                          ? TextOverflow.ellipsis
                          : null,
                      style: const TextStyle(fontSize: 10, color: _muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _asset('imgOpenSetting1', 18),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.onAccount});
  final VoidCallback onAccount;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 0,
          top: -40,
          width: 430,
          height: 90,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-.04, -.2),
                  radius: 2.48,
                  colors: [
                    Color(0xFF008F93),
                    Color(0xFF007277),
                    Color(0xFF00555B),
                  ],
                  stops: [0, .5, 1],
                  transform: _ProfileHeaderGradient(),
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          left: 25.8,
          top: 8,
          width: 84,
          height: 31,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: 25.27,
                height: 31,
                child: HomeAsset('new_imgGroup'),
              ),
              Positioned(
                right: 0,
                top: 13.16,
                width: 54.57,
                height: 15.35,
                child: HomeAsset('new_imgGroup1'),
              ),
            ],
          ),
        ),
        Positioned(
          left: 326,
          top: -1,
          child: _action(
            'Notifications',
            'imgNavigationSymbol1',
            25,
            () => context.go(AppRoutes.requests),
          ),
        ),
        Positioned(
          left: 372,
          top: -1,
          child: _action(
            'Account settings',
            'imgNavigationSymbol',
            30,
            onAccount,
          ),
        ),
      ],
    ),
  );
  Widget _action(String label, String asset, double size, VoidCallback onTap) =>
      Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 47,
              height: 47,
              child: Center(
                child: Container(
                  width: 33,
                  height: 33,
                  decoration: const BoxDecoration(
                    color: Color(0x70008D92),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: _asset(asset, size)),
                ),
              ),
            ),
          ),
        ),
      );
}

// Figma's header gradient has a 223.6 ? 62.8 elliptical radius.
class _ProfileHeaderGradient extends GradientTransform {
  const _ProfileHeaderGradient();
  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.diagonal3Values(1, .28, 1)
        ..setTranslationRaw(0, .72 * (bounds.top + bounds.height * .4), 0);
}

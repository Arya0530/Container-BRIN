import 'package:flutter/material.dart';
import 'theme.dart';

class BrinLogo extends StatelessWidget {
  const BrinLogo({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/brin_logo.png',
      width: compact ? 115 : 180,
      height: compact ? 40 : 71,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Text(
        'BRIN',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: brinDark,
          fontSize: compact ? 23 : 27,
        ),
      ),
    );
  }
}

class BrinHeader extends StatelessWidget {
  const BrinHeader({super.key, this.onMenu, this.onBack, this.onSearch});
  final VoidCallback? onMenu;
  final VoidCallback? onBack;
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 5),
      child: SizedBox(
        height: 59,
        child: Row(
          children: [
            SizedBox(
              width: 35,
              child: IconButton(
                onPressed:
                    onMenu ?? onBack ?? () => Navigator.maybePop(context),
                padding: EdgeInsets.zero,
                icon: Icon(
                  onMenu != null ? Icons.menu : Icons.arrow_back_ios_new,
                  color: brinRed,
                  size: 24,
                ),
                tooltip: onMenu != null ? 'Open menu' : 'Back',
              ),
            ),
            const Expanded(child: Center(child: BrinLogo(compact: true))),
            if (onSearch != null)
              SizedBox(
                width: 108,
                height: 34,
                child: OutlinedButton.icon(
                  onPressed: onSearch,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: brinRed,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    side: const BorderSide(color: Color(0xFFFFCBD0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.search, size: 17),
                  label: const Text(
                    'Search series',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: brinMuted),
                  ),
                ),
              )
            else
              const SizedBox(width: 35),
          ],
        ),
      ),
    );
  }
}

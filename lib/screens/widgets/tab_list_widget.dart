import 'dart:io';
import 'package:Bloomee/screens/widgets/paging_scroll.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:Bloomee/core/theme/app_theme.dart';

class CategoryLabel extends StatelessWidget {
  final String category;

  const CategoryLabel({
    Key? key,
    required this.category,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: RotatedBox(
          quarterTurns: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              category,
              style: Default_Theme.secondoryTextStyle.merge(
                const TextStyle(
                  color: Default_Theme.accentColor2,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ColumnsCards extends StatelessWidget {
  final List<Widget> list;
  final int columnSize;
  final ScrollController scrollController; // Added scrollController

  const ColumnsCards({
    Key? key,
    required this.list,
    required this.columnSize,
    required this.scrollController, // Added scrollController
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return Container();

    final double itemWidth =
        ResponsiveBreakpoints.of(context).smallerOrEqualTo(TABLET)
            ? (MediaQuery.of(context).size.width - 40) * 0.88
            : (MediaQuery.of(context).size.width - 40) * 0.48;

    final List<Widget> cards = List.generate(
      (list.length / columnSize).ceil(),
      (index) {
        final startIndex = index * columnSize;
        final endIndex = (startIndex + columnSize).clamp(0, list.length);
        final currentRow = list.sublist(startIndex, endIndex);

        return SizedBox(
          width: itemWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: currentRow,
          ),
        );
      },
    );

    return Stack(
      children: [
        SizedBox(
          height: 70 * columnSize.toDouble() + 10,
          child: ListView(
            controller: scrollController, // Use the passed scrollController
            shrinkWrap: true,
            scrollDirection: Axis.horizontal,
            physics: PagingScrollPhysics(
              itemCount: cards.length,
              viewSize: MediaQuery.of(context).size.width - 40,
            ),
            itemExtent: itemWidth,
            children: cards,
          ),
        ),
      ],
    );
  }
}

class TabSongListWidget extends StatelessWidget {
  final List<Widget> list;
  final String category;
  final int columnSize;
  final VoidCallback? onSeeAll;

  const TabSongListWidget({
    Key? key,
    required this.list,
    required this.category,
    required this.columnSize,
    this.onSeeAll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();
    final double itemWidth =
        ResponsiveBreakpoints.of(context).smallerOrEqualTo(TABLET)
            ? (MediaQuery.of(context).size.width - 40) * 0.88
            : (MediaQuery.of(context).size.width - 40) * 0.48;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 16, 8),
          child: Row(
            children: [
              Container(
                width: 3.5,
                height: 18,
                decoration: BoxDecoration(
                  color: Default_Theme.accentColor2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Default_Theme.primaryColor1,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (Platform.isWindows || Platform.isLinux) ...[
                IconButton(
                  icon: const Icon(
                    MingCute.left_line,
                    size: 18,
                    color: Default_Theme.primaryColor2,
                  ),
                  splashRadius: 18,
                  onPressed: () {
                    scrollController.animateTo(
                      scrollController.offset - itemWidth,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    MingCute.right_line,
                    size: 18,
                    color: Default_Theme.primaryColor2,
                  ),
                  splashRadius: 18,
                  onPressed: () {
                    scrollController.animateTo(
                      scrollController.offset + itemWidth,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ],
              if (onSeeAll != null)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onSeeAll,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See all',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Default_Theme.accentLavender,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          MingCute.right_line,
                          size: 14,
                          color: Default_Theme.accentLavender,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: ColumnsCards(
            list: list,
            columnSize: columnSize,
            scrollController: scrollController,
          ),
        ),
      ],
    );
  }
}

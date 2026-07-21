import 'package:flutter/material.dart';

class TabItem extends StatelessWidget {
  const TabItem({
    super.key,
    required this.id,
    required this.title,
    required this.color,
    required this.isDarkTheme,
  });

  final String id;
  final String title;
  final Color color;
  final bool isDarkTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
          child: Center(
            child: Text(
              id,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.height * 0.019,
            color: isDarkTheme ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

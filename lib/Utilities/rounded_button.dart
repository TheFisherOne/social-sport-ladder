import 'package:flutter/material.dart';
import 'package:social_sport_ladder/constants/constants.dart';
class RoundedButton extends StatelessWidget {
  final String text;
  final Function()? onTap;

  const RoundedButton({super.key,
  required this.text,
  required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tertiaryColor,
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.all(5),
        margin: const EdgeInsets.symmetric(horizontal: 5),
        child: Center(
          child: Text(text, style: nameStyle),
        )
      ),
    );
  }
}

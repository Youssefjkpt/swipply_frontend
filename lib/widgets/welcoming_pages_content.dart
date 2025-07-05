import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';

class OnboardingContent extends StatelessWidget {
  final String image, title, description;

  const OnboardingContent({
    super.key,
    required this.image,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Image.asset(
              image,
              fit: BoxFit.contain,
            ),
          ),
        ),
        SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: white,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.01),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            description,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: gray,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

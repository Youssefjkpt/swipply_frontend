import 'package:flutter/material.dart';
import 'package:swipply/constants/images.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/pages/sign_in.dart';
import 'package:swipply/widgets/welcoming_pages_content.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<Map<String, String>> onboardingData = [
    {
      "image": job_hunt,
      "title": "Trouvez l'emploi idéal",
      "description":
          "Swipez parmi des offres adaptées à votre profil et vos préférences."
    },
    {
      "image": resume,
      "title": "Postulez en un swipe",
      "description":
          "Un simple swipe pour envoyer ta candidature avec un CV personnalisé!"
    },
    {
      "image": resume,
      "title": "Lance ta carrière !",
      "description":
          "Mettez votre profil en avant et attirez l'attention des employeurs."
    }
  ];

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: black,
      body: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: onboardingData.length,
              onPageChanged: _onPageChanged,
              physics: BouncingScrollPhysics(), // Smooth swiping effect
              itemBuilder: (context, index) => OnboardingContent(
                image: onboardingData[index]["image"]!,
                title: onboardingData[index]["title"]!,
                description: onboardingData[index]["description"]!,
              ),
            ),
          ),
          SizedBox(height: 20),

          // Page Indicator Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              onboardingData.length,
              (index) => buildDot(index),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).size.height * 0.08),

          // Navigation Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_currentPage != 0) // Show "Précédent" only after first page
                GestureDetector(
                  onTap: () {
                    _pageController.previousPage(
                      duration: Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: navigationButton("Précédent", gray),
                ),
              SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  if (_currentPage == onboardingData.length - 1) {
                    // If last page, go to sign-in
                    Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (context) => SignIn()));
                  } else {
                    _pageController.nextPage(
                      duration: Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: navigationButton(
                    _currentPage == onboardingData.length - 1
                        ? "Commencer"
                        : "Suivant",
                    blue),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
        ],
      ),
    );
  }

  Widget buildDot(int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: 5),
      height: 10,
      width: _currentPage == index ? 35 : 10,
      decoration: BoxDecoration(
        color: _currentPage == index ? blue : white,
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }

  Widget navigationButton(String text, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.4,
      height: MediaQuery.of(context).size.height * 0.07,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color,
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
              color: white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

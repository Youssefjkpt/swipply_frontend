import 'package:flutter/material.dart';
import 'package:swipply/constants/themes.dart';
import 'package:swipply/pages/cv.dart';

class LanguageChipsSelector extends StatefulWidget {
  final String searchText;
  final Set<String> selectedLanguages; // ✅ Add this
  final Function(Set<String>) onSelectionChanged; // ✅ Callback to parent

  const LanguageChipsSelector({
    super.key,
    required this.searchText,
    required this.selectedLanguages,
    required this.onSelectionChanged,
  });

  @override
  State<LanguageChipsSelector> createState() => _LanguageChipsSelectorState();
}

const List<String> allLanguages = [
  'Albanais',
  'Amharique',
  'Arabe',
  'Arménien',
  'Azéri',
  'Baloutche',
  'Bengali',
  'Berbère',
  'Biélorusse',
  'Bhojpouri',
  'Bulgare',
  'Birman',
  'Catalan',
  'Chewa',
  'Chichewa',
  'Chittagonien',
  'Corse',
  'Tchèque',
  'Danois',
  'Néerlandais',
  'Anglais',
  'Fidjien',
  'Finnois',
  'Français',
  'Peul',
  'Galicien',
  'Géorgien',
  'Allemand',
  'Grec',
  'Groenlandais',
  'Gujarati',
  'Créole haïtien',
  'Haoussa',
  'Hébreu',
  'Hindi',
  'Hmong',
  'Hongrois',
  'Igbo',
  'Ilocano',
  'Indonésien',
  'Italien',
  'Japonais',
  'Javanais',
  'Kabyle',
  'Kannada',
  'Kazakh',
  'Khmer',
  'Kinyarwanda',
  'Coréen',
  'Kurde',
  'Laotien',
  'Luxembourgeois',
  'Madurais',
  'Malais',
  'Malayalam',
  'Macédonien',
  'Maori',
  'Marathi',
  'Mongol',
  'Mossi',
  'Népalais',
  'Norvégien',
  'Oromo',
  'Pachto',
  'Persan',
  'Polonais',
  'Portugais',
  'Pendjabi',
  'Quechua',
  'Roumain',
  'Russe',
  'Samoan',
  'Serbo-croate',
  'Shona',
  'Sindhi',
  'Singhalais',
  'Slovaque',
  'Somali',
  'Espagnol',
  'Swahili',
  'Suédois',
  'Soundanais',
  'Tagalog',
  'Tamoul',
  'Télougou',
  'Thaï',
  'Tigré',
  'Tigrinya',
  'Turc',
  'Ukrainien',
  'Ourdou',
  'Ouzbek',
  'Vietnamien',
  'Wolof',
  'Xhosa',
  'Yiddish',
  'Yoruba',
  'Zoulou'
];

class _LanguageChipsSelectorState extends State<LanguageChipsSelector> {
  late Set<String> localSelection;

  @override
  void initState() {
    super.initState();
    localSelection = {...widget.selectedLanguages}; // copy
  }

  @override
  Widget build(BuildContext context) {
    final filteredLanguages = allLanguages
        .where((lang) =>
            lang.toLowerCase().contains(widget.searchText.toLowerCase()))
        .toList();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: filteredLanguages.map((language) {
        final isSelected = localSelection.contains(language);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (selectedLanguages.contains(language)) {
                selectedLanguages.remove(language);
              } else {
                selectedLanguages.add(language);
              }
              widget.onSelectionChanged(localSelection); // notify parent
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? blue : blue_gray,
              borderRadius: BorderRadius.circular(100),
              border:
                  isSelected ? null : Border.all(color: white_gray, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
            child: Text(
              language,
              style: TextStyle(
                color: isSelected ? black : white_gray,
                fontSize: 15,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

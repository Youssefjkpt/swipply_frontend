// lib/constants/job_categories.dart
// -----------------------------------------------------------------------------
//  Keyword → Category matcher for the job filter sheet
// -----------------------------------------------------------------------------

/// Lower-cases and removes accents so “Médecine” == “medecine”.
String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[áàâä]'), 'a')
    .replaceAll(RegExp(r'[éèêë]'), 'e')
    .replaceAll(RegExp(r'[íìîï]'), 'i')
    .replaceAll(RegExp(r'[óòôö]'), 'o')
    .replaceAll(RegExp(r'[úùûü]'), 'u')
    .replaceAll('ç', 'c');
const List<String> kJobCategories = [
  'Tout', // keep “All” at index 0 for convenience
  'éducation',
  'santé',
  'informatique',
  'ingénierie',
  'construction',
  'commerce',
  'juridique',
  'marketing',
  'logistique',
  'transport',
  'agriculture',
  'industrie',
  'restauration',
  'hôtellerie',
  'tourisme',
  'administration',
  'finances',
  'sciences et recherche',
  'arts',
  'médias',
  'mode',
  'sécurité',
  'environnement et énergie',
  'immobiliers',
  'sports',
  'métiers manuels',
  'conseil',
  'télécommunications',
  'divertissement',
  'aide à la personne',
];

/// Master map:  <official category> → [keywords & synonyms]
final Map<String, List<String>> kJobCategoryKeywords = {
  'éducation': [
    'éducation',
    'enseignement',
    'pédagogie',
    'école',
    'professeur',
    'apprentissage',
    'soutien',
    'scolaire',
    'universite',
    'eleve'
  ],
  'santé': [
    'santé',
    'médecine',
    'soins',
    'hôpital',
    'infirmier',
    'soignant',
    'clinique'
  ],
  'informatique': [
    'informatique',
    'programmation',
    'algorithme',
    'réseau',
    'data',
    'donnees',
    'logiciel',
    'cybersécurité',
    'application',
    'intelligence artificielle',
    'developpeur',
    'full stack'
  ],
  'ingénierie': [
    'ingénierie',
    'ingenieur',
    'mécanique',
    'civil',
    'électronique',
    'technicien'
  ],
  'construction': [
    'construction',
    'bâtiment',
    'travaux',
    'chantier',
    'maçon',
    'architecte',
    'charpante',
    'maison'
  ],
  'commerce': ['commerce', 'vente', 'client', 'magasin', 'commercial'],
  'juridique': [
    'juridique',
    'droit',
    'justice',
    'avocat',
    'juriste',
    'contrat',
    'litige',
    'notaire',
    'légal'
  ],
  'marketing': [
    'marketing',
    'promotion',
    'communication',
    'publicité',
    'digital',
    'analyse',
    'marché',
    'media'
  ],
  'logistique': [
    'logistique',
    'gestion',
    'stock',
    'transport',
    'inventaire',
    'distribution',
    'approvisionnement',
    'entrepot'
  ],
  'transport': [
    'transport',
    'déplacement',
    'chauffeur',
    'logistique',
    'conduite',
    'véhicule',
    'livraison',
    'flotte',
    'voiture',
    'camion'
  ],
  'agriculture': [
    'agriculture',
    'élevage',
    'ferme',
    'récolte',
    'agriculteur',
    'animaux',
    'jardin'
  ],
  'industrie': ['industrie', 'usine', 'fabrique', 'production', 'machinerie'],
  'restauration': [
    'restauration',
    'cuisine',
    'restaurant',
    'chef',
    'serveur',
    'repas',
    'alimentaire'
  ],
  'hôtellerie': [
    'hôtellerie',
    'accueil',
    'réception',
    'chambres',
    'serveur',
    'hotel'
  ],
  'tourisme': ['tourisme', 'voyage', 'guide'],
  'administration': [
    'administration',
    'gestion',
    'secrétariat',
    'rh',
    'ressources humaines',
    'organisation'
  ],
  'finances': [
    'finances',
    'comptabilité',
    'analyse financière',
    'budget',
    'banque',
    'investissement',
    'fonds',
    'bourse',
    'argent'
  ],
  'sciences et recherche': [
    'sciences et recherche',
    'laboratoire',
    'expérimentation',
    'scientifique',
    'chimie',
    'physique',
    'biologie'
  ],
  'arts': [
    'arts',
    'peinture',
    'sculpture',
    'design',
    'illustration',
    'artistique'
  ],
  'médias': [
    'médias',
    'journalisme',
    'rédaction',
    'presse',
    'reportage',
    'reseaux sociaux',
    'contenu'
  ],
  'mode': ['mode', 'design', 'vetements', 'style', 'textile', 'couture'],
  'sécurité': [
    'sécurité',
    'protection',
    'surveillance',
    'agent de sécurité',
    'pompier',
    'police'
  ],
  'environnement et énergie': [
    'environnement',
    'énergie',
    'développement durable',
    'écologie',
    'énergie renouvelable',
    'solaire',
    'photovoltaique',
    'eau',
    'vent',
    'déchets'
  ],
  'immobiliers': [
    'immobiliers',
    'location',
    'agence',
    'propriété',
    'promoteur',
    'maison'
  ],
  'sports': [
    'sports',
    'entraînement',
    'coach',
    'compétition',
    'equipe de sport'
  ],
  'métiers manuels': [
    'métiers manuels',
    'artisanat',
    'réparation',
    'électricité',
    'plomberie',
    'menuiserie',
    'bricolage'
  ],
  'conseil': [
    'conseil',
    'accueil',
    'accompagnement',
    'consultant',
    'aide',
    'personnes',
    'gestion client'
  ],
  'télécommunications': [
    'télécommunications',
    'réseaux',
    'installation',
    'radio',
    'tele',
    'ingénieur télécom'
  ],
  'divertissement': [
    'divertissement',
    'spectacle',
    'animation',
    'musique',
    'théâtre',
    'comédie',
    'film',
    'jeux video'
  ],
  'aide à la personne': [
    'aide à la personne',
    'assistance',
    'soins',
    'aide',
    'domicile',
    'garde',
    'enfant',
    'vieux'
  ],
};

/// Lookup table built once at import time:
///   "reseau"  → "informatique"
///   "chef"    → "restauration"
///   "informatique" → "informatique" (category names themselves included)
final Map<String, String> kKeywordToCategory = (() {
  final m = <String, String>{};
  kJobCategoryKeywords.forEach((cat, words) {
    m[_norm(cat)] = cat;
    for (final w in words) m[_norm(w)] = cat;
  });
  return m;
})();

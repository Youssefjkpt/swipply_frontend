import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:swipply/constants/themes.dart';
import 'package:swipply/pages/sign_in.dart';
import 'package:swipply/pages/welcoming_pages.dart';

/// Doubles both drag distance and fling momentum.
class DoubleSpeedScrollPhysics extends ClampingScrollPhysics {
  const DoubleSpeedScrollPhysics({super.parent});

  @override
  DoubleSpeedScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      DoubleSpeedScrollPhysics(parent: buildParent(ancestor));

  // 2× the distance for every finger‑move.
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      super.applyPhysicsToUserOffset(position, offset * 2);

  // 2× the initial velocity so flings travel further.
  @override
  Simulation? createBallisticSimulation(
          ScrollMetrics position, double velocity) =>
      super.createBallisticSimulation(position, velocity * 2);
}

/* ────────────────────────────────────────────────────────────────────────────
   TERMS & CONDITIONS PAGE  –  final polish (FR version)
   ────────────────────────────────────────────────────────────────────────────
   🔹  Black background (matches global theme).
   🔹  "Accepter" button turns **bright blue as soon as the checkbox is ticked**
       – even if the user hasn’t reached the bottom yet – to give immediate
       feedback.  The tap is still blocked until they’ve scrolled to the end;
       a SnackBar explains why.
   🔹  Reliable bottom‑detection via ScrollController listener.
*/
class TermsConditionsPage extends StatefulWidget {
  const TermsConditionsPage({super.key});

  @override
  State<TermsConditionsPage> createState() => _TermsConditionsPageState();
}

class _TermsConditionsPageState extends State<TermsConditionsPage> {
  final ScrollController _scroll = ScrollController();
  bool _atBottom = false;
  bool _agreed = false;

  bool get _canProceed => _agreed && _atBottom;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;

    final pos = _scroll.position;
    final reached =
        pos.pixels + pos.viewportDimension >= pos.maxScrollExtent - 4;

    if (reached != _atBottom) {
      setState(() => _atBottom = reached);
    }
  }

  /// Politique de confidentialité – version intégrale (aucune abréviation)
  final List<String> _privacyPolicyLines = [
    // ───── ENTÊTE ─────
    'Politique de confidentialité',
    'Dernière mise à jour le 11 juillet 2025',
    '',

    // ───── INTRODUCTION ─────
    'Cet avis de confidentialité pour Swipply (« nous », « notre ») décrit comment et pourquoi nous pouvons accéder, collecter, stocker, utiliser et/ou partager (« traiter ») vos informations personnelles lorsque vous utilisez nos services (« Services »), y compris lorsque vous :',
    'Téléchargez et utilisez notre application mobile (Swipply), ou toute autre application de notre part qui renvoie à cet avis de confidentialité',
    'Utilisez Swipply, une plateforme qui simplifie les candidatures en envoyant automatiquement les informations de l’utilisateur au recruteur, par simple glissement',
    'Vous engagez avec nous d’autres manières connexes, y compris les ventes, le marketing ou les événements',
    '',
    'Des questions ou des préoccupations ? La lecture de cette Politique de confidentialité vous aidera à comprendre vos droits et vos choix en matière de confidentialité. Nous sommes responsables du traitement de vos informations personnelles. Si vous n’acceptez pas nos politiques et pratiques, veuillez ne pas utiliser nos Services. Pour toute question ou préoccupation, veuillez nous contacter à l’adresse suivante : swipply.contact@gmail.com.',
    '',

    // ───── RÉSUMÉ DES POINTS CLÉS ─────
    'RÉSUMÉ DES POINTS CLÉS',
    'Ce résumé fournit les points clés de notre avis de confidentialité, mais vous pouvez trouver plus de détails sur l’un de ces sujets en cliquant sur le lien suivant chaque point clé ou en utilisant notre table des matières ci‑dessous pour trouver la section que vous recherchez.',
    'Quelles informations personnelles traitons‑nous ? Lorsque vous visitez, utilisez ou naviguez sur nos Services, nous pouvons traiter des informations personnelles en fonction de la manière dont vous interagissez avec nous et les Services, des choix que vous faites et des produits et fonctionnalités que vous utilisez.',
    'Traitons‑nous des informations personnelles sensibles ? Certaines informations peuvent être considérées comme « spéciales » ou « sensibles » dans certaines juridictions, par exemple vos origines raciales ou ethniques, votre orientation sexuelle et vos croyances religieuses. Nous pouvons traiter des informations personnelles sensibles si nécessaire, avec votre consentement ou conformément à la loi applicable.',
    'Collectons‑nous des informations auprès de tiers ? Nous ne collectons aucune information auprès de tiers.',
    'Comment traitons‑nous vos informations ? Nous traitons vos informations pour fournir, améliorer et administrer nos Services, communiquer avec vous, assurer la sécurité et la prévention de la fraude, et respecter la loi. Nous pouvons également traiter vos informations à d’autres fins avec votre consentement. Nous ne traitons vos informations que lorsque nous avons une raison légale valable de le faire.',
    'Dans quelles situations et avec quelles parties partageons‑nous des informations personnelles ? Nous pouvons partager des informations dans des situations spécifiques et avec des tiers spécifiques.',
    'Quels sont vos droits ? Selon l’endroit où vous vous trouvez géographiquement, la loi applicable en matière de confidentialité peut signifier que vous disposez de certains droits concernant vos informations personnelles.',
    'Comment exercer vos droits ? Le moyen le plus simple d’exercer vos droits est de soumettre une demande d’accès aux données personnelles ou de nous contacter. Nous examinerons et traiterons toute demande conformément aux lois applicables en matière de protection des données.',
    'Vous souhaitez en savoir plus sur l’utilisation des informations que nous collectons ? Consultez l’intégralité de notre Avis de confidentialité.',
    '',

    // ───── TABLE DES MATIÈRES ─────
    'TABLE DES MATIÈRES',
    '1. QUELLES INFORMATIONS COLLECTONS‑NOUS ?',
    '2. COMMENT TRAITONS‑NOUS VOS INFORMATIONS ?',
    '3. SUR QUELLES BASES JURIDIQUES NOUS APPUYONS‑NOUS POUR TRAITER VOS INFORMATIONS PERSONNELLES ?',
    '4. QUAND ET AVEC QUI PARTAGEONS‑NOUS VOS INFORMATIONS PERSONNELLES ?',
    '5. OFFRONS‑NOUS DES PRODUITS BASÉS SUR L’INTELLIGENCE ARTIFICIELLE ?',
    '6. COMMENT GÉRONS‑NOUS VOS CONNEXIONS SOCIALES ?',
    '7. COMBIEN DE TEMPS CONSERVONS‑NOUS VOS INFORMATIONS ?',
    '8. COLLECTONS‑NOUS DES INFORMATIONS AUPRÈS DES MINEURS ?',
    '9. QUELS SONT VOS DROITS EN MATIÈRE DE CONFIDENTIALITÉ ?',
    '10. COMMANDES POUR LES FONCTIONNALITÉS DE NON‑SUIVI',
    '11. METTONS‑NOUS À JOUR CET AVIS ?',
    '12. COMMENT POUVEZ‑VOUS NOUS CONTACTER AU SUJET DE CET AVIS ?',
    '13. COMMENT POUVEZ‑VOUS CONSULTER, METTRE À JOUR OU SUPPRIMER LES DONNÉES QUE NOUS RECUEILLONS À VOTRE SUJET ?',
    '',

    // ───── SECTION 1 ─────
    '1. QUELLES INFORMATIONS COLLECTONS‑NOUS ?',
    'Informations personnelles que vous nous divulguez.',
    'En bref : Nous collectons les informations personnelles que vous nous fournissez.',
    'Nous collectons les informations personnelles que vous nous fournissez volontairement lorsque vous vous inscrivez sur les Services, exprimez un intérêt à obtenir des informations sur nous ou nos produits et Services, lorsque vous participez à des activités sur les Services, ou autrement lorsque vous nous contactez.',
    'Informations personnelles fournies par vous.',
    'Les informations personnelles que nous collectons dépendent du contexte de vos interactions avec nous et les Services, de vos choix et des produits et fonctionnalités que vous utilisez. Les informations personnelles que nous collectons peuvent inclure les éléments suivants :',
    ' nom',
    ' numéro de téléphone',
    ' adresse e‑mail',
    ' titres de poste',
    ' mot de passe',
    ' numéro de carte de débit/crédit',
    ' adresse de facturation',
    'Informations sensibles.',
    'Lorsque cela est nécessaire, avec votre consentement ou comme autrement autorisé par la loi applicable, nous traitons les catégories d’informations sensibles suivantes :',
    ' données financières',
    ' informations révélant la race ou l’origine ethnique',
    ' données sur les étudiants',
    'Données de paiement : nous pouvons collecter les données nécessaires au traitement de votre paiement si vous choisissez d’effectuer des achats, telles que votre numéro d’instrument de paiement et le code de sécurité associé. Toutes les données de paiement sont traitées et stockées par Stripe et Apple Pay. Vous trouverez leurs avis de confidentialité ici : https://stripe.com/privacy et https://www.apple.com/legal/privacy/data/fr/apple-pay/.',
    'Données de connexion aux réseaux sociaux : nous pouvons vous proposer de vous inscrire en utilisant vos identifiants de réseaux sociaux, comme Facebook, X ou tout autre compte. Si vous choisissez de vous inscrire de cette manière, nous collecterons certaines informations de profil vous concernant auprès du fournisseur de réseaux sociaux, comme décrit dans la section « COMMENT GÉRONS‑NOUS VOS CONNEXIONS SOCIALES ? » ci‑dessous.',
    'Toutes les informations personnelles que vous nous fournissez doivent être vraies, complètes et exactes, et vous devez nous informer de tout changement apporté à ces informations personnelles.',
    '',

    // ───── SECTION 2 ─────
    '2. COMMENT TRAITONS‑NOUS VOS INFORMATIONS ?',
    'En bref : Nous traitons vos informations pour fournir, améliorer et administrer nos services, communiquer avec vous, assurer la sécurité et la prévention de la fraude, et respecter la loi. Nous pouvons également traiter vos informations à d’autres fins avec votre consentement.',
    'Nous traitons vos informations personnelles pour diverses raisons, en fonction de la manière dont vous interagissez avec nos Services, notamment :',
    ' Pour faciliter la création et l’authentification des comptes et gérer les comptes utilisateurs. Nous pouvons traiter vos informations afin que vous puissiez créer et vous connecter à votre compte, ainsi que maintenir votre compte en état de fonctionnement.',
    ' Fournir et faciliter la fourniture de services à l’utilisateur. Nous pouvons traiter vos informations pour vous fournir le service demandé.',
    ' Pour sauver ou protéger l’intérêt vital d’un individu. Nous pouvons traiter vos informations lorsque cela est nécessaire pour sauvegarder ou protéger l’intérêt vital d’un individu, par exemple pour prévenir un préjudice.',
    '',

    // ───── SECTION 3 ─────
    '3. SUR QUELLES BASES JURIDIQUES NOUS APPUYONS‑NOUS POUR TRAITER VOS INFORMATIONS ?',
    'En bref : Nous traitons vos informations personnelles uniquement lorsque nous pensons que cela est nécessaire et que nous avons une raison légale valable (c’est‑à‑dire une base légale) de le faire en vertu de la loi applicable, comme avec votre consentement, pour nous conformer aux lois, pour vous fournir des services pour conclure ou remplir nos obligations contractuelles, pour protéger vos droits ou pour satisfaire nos intérêts commerciaux légitimes.',
    'Le Règlement général sur la protection des données (RGPD) et le RGPD britannique nous obligent à expliquer les bases juridiques sur lesquelles nous nous appuyons pour traiter vos informations personnelles. Ainsi, nous pouvons nous appuyer sur les bases juridiques suivantes pour traiter vos informations personnelles :',
    ' Consentement : nous pouvons traiter vos informations si vous nous avez donné votre autorisation (votre consentement) pour utiliser vos informations personnelles à des fins spécifiques. Vous pouvez retirer votre consentement à tout moment.',
    ' Exécution d’un contrat : nous pouvons traiter vos informations personnelles lorsque nous pensons que cela est nécessaire pour remplir nos obligations contractuelles envers vous, y compris la fourniture de nos Services ou à votre demande avant de conclure un contrat avec vous.',
    ' Obligations légales : nous pouvons traiter vos informations lorsque nous pensons que cela est nécessaire au respect de nos obligations légales, par exemple pour coopérer avec un organisme chargé de l’application de la loi ou un organisme de réglementation, exercer ou défendre nos droits légaux, ou divulguer vos informations comme preuve dans un litige dans lequel nous sommes impliqués.',
    ' Intérêts vitaux : nous pouvons traiter vos informations lorsque nous pensons que cela est nécessaire pour protéger vos intérêts vitaux ou les intérêts vitaux d’un tiers, comme dans des situations impliquant des menaces potentielles pour la sécurité de toute personne.',
    '',

    // ───── SECTION 4 ─────
    '4. QUAND ET AVEC QUI PARTAGEONS‑NOUS VOS INFORMATIONS PERSONNELLES ?',
    'En bref : Nous pouvons partager des informations dans des situations spécifiques décrites dans cette section et/ou avec les tiers suivants.',
    'Nous pouvons être amenés à partager vos informations personnelles dans les situations suivantes :',
    ' Transferts d’entreprises : nous pouvons partager ou transférer vos informations dans le cadre ou au cours de négociations relatives à toute fusion, vente d’actifs de l’entreprise, financement ou acquisition de tout ou partie de notre entreprise à une autre entreprise.',
    '',

    // ───── SECTION 5 ─────
    '5. OFFRONS‑NOUS DES PRODUITS BASÉS SUR L’INTELLIGENCE ARTIFICIELLE ?',
    'En bref : Nous proposons des produits, des fonctionnalités ou des outils basés sur l’intelligence artificielle, l’apprentissage automatique ou des technologies similaires.',
    'Dans le cadre de nos Services, nous proposons des produits, fonctionnalités ou outils basés sur l’intelligence artificielle, l’apprentissage automatique ou des technologies similaires (collectivement, les « Produits d’intelligence artificielle »). Ces outils sont conçus pour améliorer votre expérience et vous fournir des solutions innovantes.',
    'Utilisation des technologies d’intelligence artificielle : nous fournissons les Produits d’intelligence artificielle par l’intermédiaire de prestataires de services tiers (« Prestataires de Services d’intelligence artificielle »), dont OpenAI. Comme indiqué dans la présente Déclaration de confidentialité, vos données d’entrée, de sortie et vos informations personnelles seront partagées avec ces prestataires de services d’intelligence artificielle et traitées par eux afin de vous permettre d’utiliser nos Produits d’intelligence artificielle aux fins décrites dans la section « Sur quelles bases juridiques nous appuyons‑nous pour traiter vos informations personnelles ? ». Vous ne devez pas utiliser les Produits d’intelligence artificielle d’une manière qui contrevienne aux conditions ou aux politiques de tout prestataire de services d’intelligence artificielle.',
    'Nos Produits d’intelligence artificielle sont conçus pour les fonctions suivantes :',
    ' Génération de documents par intelligence artificielle',
    ' Traitement du langage naturel',
    ' Identification des emplois susceptibles d’intéresser l’utilisateur',
    'Comment nous traitons vos données à l’aide de l’intelligence artificielle : toutes les informations personnelles traitées par nos Produits d’intelligence artificielle sont traitées conformément à notre Avis de confidentialité et à notre accord avec des tiers. Cela garantit une sécurité élevée et protège vos informations personnelles tout au long du processus, vous offrant ainsi une tranquillité d’esprit quant à la sécurité de vos données.',
    '',

    // ───── SECTION 6 ─────
    '6. COMMENT GÉRONS‑NOUS VOS CONNEXIONS SOCIALES ?',
    'En bref : si vous choisissez de vous inscrire ou de vous connecter à nos Services à l’aide d’un compte de réseau social, nous pouvons avoir accès à certaines informations vous concernant.',
    'Nos Services vous offrent la possibilité de vous inscrire et de vous connecter à l’aide des identifiants de votre compte de réseau social tiers (comme vos identifiants Facebook, X ou Google). Si vous choisissez cette option, nous recevrons certaines informations de profil vous concernant de la part de votre fournisseur de réseau social. Ces informations peuvent varier selon le fournisseur concerné, mais incluront généralement votre nom, votre adresse e‑mail, votre liste d’amis et votre photo de profil, ainsi que d’autres informations que vous choisissez de rendre publiques sur ce réseau social.',
    'Nous utiliserons les informations que nous recevons uniquement aux fins décrites dans la présente Politique de confidentialité ou qui vous sont clairement indiquées sur les Services concernés. Veuillez noter que nous ne contrôlons pas et ne sommes pas responsables des autres utilisations de vos informations personnelles par votre fournisseur de réseaux sociaux tiers. Nous vous recommandons de consulter leur politique de confidentialité pour comprendre comment ils collectent, utilisent et partagent vos informations personnelles, et comment vous pouvez paramétrer vos préférences de confidentialité sur leurs sites et applications.',
    '',

    // ───── SECTION 7 ─────
    '7. COMBIEN DE TEMPS CONSERVONS‑NOUS VOS INFORMATIONS ?',
    'En bref : Nous conservons vos informations aussi longtemps que nécessaire pour atteindre les objectifs décrits dans la présente déclaration de confidentialité, sauf si la loi l’exige autrement.',
    'Nous conserverons vos informations personnelles uniquement pendant la durée nécessaire aux fins énoncées dans la présente Politique de confidentialité, sauf si une période de conservation plus longue est requise ou autorisée par la loi (par exemple, pour des raisons fiscales, comptables ou autres). Aucune des finalités de la présente Politique ne nous oblige à conserver vos informations personnelles au‑delà de la durée de validité de votre compte.',
    'Lorsque nous n’avons aucun besoin commercial légitime et continu de traiter vos informations personnelles, nous supprimerons ou anonymiserons ces informations ou, si cela n’est pas possible (par exemple, parce que vos informations personnelles ont été stockées dans des archives de sauvegarde), nous stockerons vos informations personnelles en toute sécurité et les isolerons de tout traitement ultérieur jusqu’à ce que la suppression soit possible.',
    '',

    // ───── SECTION 8 ─────
    '8. COLLECTONS‑NOUS DES INFORMATIONS AUPRÈS DES MINEURS ?',
    'En bref : nous ne collectons pas sciemment de données auprès d’enfants de moins de 18 ans et ne faisons pas de marketing auprès d’eux.',
    'Nous ne collectons, ne sollicitons ni ne commercialisons sciemment de données auprès d’enfants de moins de 18 ans, et ne vendons pas sciemment de telles informations personnelles. En utilisant les Services, vous déclarez avoir au moins 18 ans ou être le parent ou le tuteur d’un mineur et consentez à son utilisation des Services. Si nous apprenons que des informations personnelles d’utilisateurs de moins de 18 ans ont été collectées, nous désactiverons le compte et prendrons des mesures raisonnables pour supprimer rapidement ces données de nos archives. Si vous avez connaissance de données que nous aurions collectées auprès d’enfants de moins de 18 ans, veuillez nous contacter à l’adresse suivante : swipply.contact@gmail.com.',
    '',

    // ───── SECTION 9 ─────
    '9. QUELS SONT VOS DROITS EN MATIÈRE DE CONFIDENTIALITÉ ?',
    'En bref : Dans certaines régions, comme l’Espace économique européen (EEE), le Royaume‑Uni et la Suisse, vous disposez de droits vous permettant d’accéder et de contrôler vos informations personnelles. Vous pouvez consulter, modifier ou résilier votre compte à tout moment, selon votre pays, province ou État de résidence.',
    'Dans certaines régions (comme l’EEE, le Royaume‑Uni et la Suisse), vous disposez de certains droits en vertu des lois applicables en matière de protection des données. Ceux‑ci peuvent inclure le droit (i) de demander l’accès à vos informations personnelles et d’en obtenir une copie ; (ii) de demander leur rectification ou leur effacement ; (iii) de restreindre le traitement de vos informations personnelles ; (iv) le cas échéant, la portabilité des données ; et (v) de ne pas faire l’objet d’une prise de décision automatisée. Dans certaines circonstances, vous pouvez également avoir le droit de vous opposer au traitement de vos informations personnelles. Vous pouvez adresser cette demande en nous contactant aux coordonnées indiquées dans la section « COMMENT POUVEZ‑VOUS NOUS CONTACTER AU SUJET DE CET AVIS ? » ci‑dessous.',
    'Nous examinerons et traiterons toute demande conformément aux lois applicables en matière de protection des données.',
    'Si vous êtes situé dans l’EEE ou au Royaume‑Uni et que vous pensez que nous traitons illégalement vos informations personnelles, vous avez également le droit de déposer une plainte auprès de l’autorité de protection des données de votre État membre ou de l’autorité de protection des données du Royaume‑Uni.',
    'Si vous êtes situé en Suisse, vous pouvez contacter le Préposé fédéral à la protection des données et à la transparence.',
    'Retrait de votre consentement : Si nous nous appuyons sur votre consentement pour traiter vos informations personnelles, vous avez le droit de le retirer à tout moment. Vous pouvez le faire en nous contactant aux coordonnées indiquées dans la section « COMMENT POUVEZ‑VOUS NOUS CONTACTER AU SUJET DE CET AVIS ? » ci‑dessous.',
    'Toutefois, veuillez noter que cela n’affectera pas la légalité du traitement avant son retrait ni le traitement de vos informations personnelles effectué sur la base de motifs de traitement légaux autres que le consentement.',
    'Informations sur le compte : Si vous souhaitez à tout moment consulter ou modifier les informations de votre compte ou résilier votre compte, vous pouvez :',
    ' Nous contacter en utilisant les coordonnées fournies',
    'À votre demande de résiliation de compte, nous désactiverons ou supprimerons votre compte et vos informations de nos bases de données actives. Cependant, nous pouvons conserver certaines informations dans nos fichiers pour prévenir la fraude, résoudre des problèmes, faciliter les enquêtes, faire respecter nos conditions générales et/ou nous conformer aux exigences légales applicables.',
    'Si vous avez des questions ou des commentaires sur vos droits en matière de confidentialité, vous pouvez nous envoyer un e‑mail à swipply.contact@gmail.com.',
    '',

    // ───── SECTION 10 ─────
    '10. COMMANDES POUR LES FONCTIONNALITÉS DE NON‑SUIVI',
    'La plupart des navigateurs web et certains systèmes d’exploitation et applications mobiles incluent une fonctionnalité ou un paramètre « Do Not Track » (« DNT ») que vous pouvez activer pour signaler votre préférence de confidentialité et refuser la surveillance et la collecte des données relatives à vos activités de navigation en ligne. À ce stade, aucune norme technologique uniforme pour la reconnaissance et la mise en œuvre des signaux DNT n’a été finalisée. Par conséquent, nous ne répondons pas actuellement aux signaux DNT des navigateurs ni à tout autre mécanisme communiquant automatiquement votre choix de ne pas être suivi en ligne. Si une norme de suivi en ligne est adoptée et que nous devons la suivre à l’avenir, nous vous en informerons dans une version révisée de la présente Politique de confidentialité.',
    '',

    // ───── SECTION 11 ─────
    '11. METTONS‑NOUS À JOUR CET AVIS ?',
    'En bref : Oui, nous mettrons à jour cet avis si nécessaire pour rester conformes aux lois en vigueur.',
    'Nous sommes susceptibles de mettre à jour la présente Politique de confidentialité de temps à autre. La date de mise à jour sera indiquée en haut de la présente Politique de confidentialité par la mention « Révisé ». Si nous apportons des modifications importantes à la présente Politique de confidentialité, nous pourrons vous en informer soit en publiant un avis bien en vue, soit en vous envoyant directement une notification. Nous vous encourageons à consulter régulièrement la présente Politique de confidentialité afin de vous tenir informé de la manière dont nous protégeons vos informations.',
    '',

    // ───── SECTION 12 ─────
    '12. COMMENT POUVEZ‑VOUS NOUS CONTACTER AU SUJET DE CET AVIS ?',
    'Si vous avez des questions ou des commentaires sur cet avis, vous pouvez nous envoyer un e‑mail à swipply.contact@gmail.com — Swipply, basé à Paris.',
    '',

    // ───── SECTION 13 ─────
    '13. COMMENT POUVEZ‑VOUS CONSULTER, METTRE À JOUR OU SUPPRIMER LES DONNÉES QUE NOUS RECUEILLONS À VOTRE SUJET ?',
    'Selon la législation applicable dans votre pays, vous pouvez demander l’accès aux informations personnelles que nous collectons, des informations sur leur traitement, la correction d’éventuelles inexactitudes ou leur suppression. Vous pouvez également retirer votre consentement au traitement de vos informations personnelles. Ces droits peuvent être limités dans certaines circonstances par la législation applicable. Pour demander la consultation, la mise à jour ou la suppression de vos informations personnelles, veuillez remplir et soumettre une demande d’accès aux données personnelles.',
  ];

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _saveConsent() async {
    // TODO(backend): replace placeholders
    const token = '<AUTH_TOKEN>';
    const url = '<API_BASE>/consents';
    try {
      await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'sale': true,
          'policy_version': '2025-07-01',
          'granted_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Consent save failed → $e');
    }
  }

  void _maybeShowScrollHint() {
    if (_agreed && !_atBottom) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Faites défiler jusqu\'en bas pour activer « Accepter ».'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              children: const [
                SizedBox(width: 20),
                Text('Accord',
                    style: TextStyle(
                        fontSize: 18,
                        color: Color.fromARGB(255, 151, 152, 156))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: const [
                SizedBox(width: 20),
                Text('Conditions générales',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: blue)),
              ],
            ),
            const SizedBox(height: 20),

            // ─── contenu déroulable ───
            Expanded(
              child: SingleChildScrollView(
                controller: _scroll,
                physics: const DoubleSpeedScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // On applique un style différent pour les en‑têtes (gras + taille plus grande).
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _privacyPolicyLines.map((line) {
                        if (line.isEmpty) {
                          return const SizedBox(height: 12);
                        }
                        final bool isHeading = RegExp(
                                r'^(\d+\.|RÉSUMÉ|TABLE|Politique de confidentialité|Dernière mise)')
                            .hasMatch(line);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            line,
                            style: TextStyle(
                              fontSize: isHeading ? 14.5 : 12,
                              fontWeight: isHeading
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: white,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreed,
                          activeColor: blue,
                          checkColor: black,
                          side: const BorderSide(color: white_gray),
                          onChanged: (v) =>
                              setState(() => _agreed = v ?? false),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'J\'ai lu et j\'accepte la Politique de confidentialité, y compris la vente/partage de mes données.',
                                style: TextStyle(
                                    fontSize: 13.5, color: white_gray),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  // TODO(ui): open policy URL
                                },
                                child: const Text('Voir la politique complète',
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        color: blue,
                                        decoration: TextDecoration.underline)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ─── boutons inférieurs ───
            Container(
              color: black,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => OnboardingScreen())),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.07,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF303030),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Refuser',
                            style: TextStyle(
                                fontSize: 16,
                                color: white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        if (_canProceed) {
                          await _saveConsent();
                          if (mounted) {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => SignIn()));
                          }
                        } else {
                          _maybeShowScrollHint();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: MediaQuery.of(context).size.height * 0.07,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _agreed ? blue : blue.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Accepter',
                            style: TextStyle(
                                fontSize: 16,
                                color: white,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ────────────────────────────────────────────────────────────────────────────
   BACKEND TODOs                                                            
   ────────────────────────────────────────────────────────────────────────────
   • Replace <AUTH_TOKEN> / <API_BASE> with real values.                   
   • Implement policy deep‑link in the onTap callback.                     
*/

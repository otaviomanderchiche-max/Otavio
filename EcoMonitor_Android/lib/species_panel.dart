import 'package:flutter/material.dart';

class SpeciesRule {
  final String name;
  final String scientificName;
  final double minTemp;
  final double maxTemp;
  final double targetHumidity;
  final String imageAsset;

  const SpeciesRule({
    required this.name,
    required this.scientificName,
    required this.minTemp,
    required this.maxTemp,
    required this.targetHumidity,
    required this.imageAsset,
  });
}

class SpeciesResult {
  final SpeciesRule species;
  final int score;

  const SpeciesResult({required this.species, required this.score});
}

const List<SpeciesRule> kSpeciesCatalog = [
  SpeciesRule(
    name: 'Ipê-amarelo',
    scientificName: 'Handroanthus albus',
    minTemp: 10,
    maxTemp: 20,
    targetHumidity: 40,
    imageAsset: 'assets/especies/ipe_amarelo.jpg',
  ),
  SpeciesRule(
    name: 'Araucária',
    scientificName: 'Araucaria angustifolia',
    minTemp: 15,
    maxTemp: 20,
    targetHumidity: 80,
    imageAsset: 'assets/especies/araucaria.jpg',
  ),
  SpeciesRule(
    name: 'Jequitibá-rosa',
    scientificName: 'Cariniana legalis',
    minTemp: 19,
    maxTemp: 28,
    targetHumidity: 80,
    imageAsset: 'assets/especies/jequitiba_rosa.jpg',
  ),
  SpeciesRule(
    name: 'Mogno / Jatobá',
    scientificName: 'Swietenia macrophylla / Hymenaea courbaril',
    minTemp: 20,
    maxTemp: 25,
    targetHumidity: 50,
    imageAsset: 'assets/especies/mogno_jatoba.jpg',
  ),
  SpeciesRule(
    name: 'Jacarandá da Bahia',
    scientificName: 'Dalbergia nigra',
    minTemp: 20,
    maxTemp: 30,
    targetHumidity: 75,
    imageAsset: 'assets/especies/jacaranda_bahia.jpg',
  ),
  SpeciesRule(
    name: 'Pau-Brasil / Guapuruvu',
    scientificName: 'Paubrasilia echinata / Schizolobium parahyba',
    minTemp: 25,
    maxTemp: 30,
    targetHumidity: 70,
    imageAsset: 'assets/especies/pau_brasil.jpg',
  ),
  SpeciesRule(
    name: 'Pau-ferro',
    scientificName: 'Libidibia ferrea',
    minTemp: 20,
    maxTemp: 32,
    targetHumidity: 60,
    imageAsset: 'assets/especies/pau_ferro.jpg',
  ),
  SpeciesRule(
    name: 'Angico',
    scientificName: 'Anadenanthera colubrina',
    minTemp: 22,
    maxTemp: 35,
    targetHumidity: 15,
    imageAsset: 'assets/especies/angico.jpg',
  ),
];

List<SpeciesResult> rankSpecies({required double temperature, required double humidity}) {
  final results = kSpeciesCatalog.map((species) {
    final score = _compatibilityScore(
      temperature: temperature,
      humidity: humidity,
      species: species,
    );
    return SpeciesResult(species: species, score: score);
  }).toList();

  results.sort((a, b) => b.score.compareTo(a.score));
  return results;
}

int _compatibilityScore({
  required double temperature,
  required double humidity,
  required SpeciesRule species,
}) {
  final tempScore = _intervalScore(
    value: temperature,
    min: species.minTemp,
    max: species.maxTemp,
    outsideTolerance: 12,
  );

  final humidityScore = _targetScore(
    value: humidity,
    target: species.targetHumidity,
    tolerance: 35,
  );

  final score = (tempScore * 0.58) + (humidityScore * 0.42);
  return score.round().clamp(0, 100);
}

double _intervalScore({
  required double value,
  required double min,
  required double max,
  required double outsideTolerance,
}) {
  if (value >= min && value <= max) return 100;
  final distance = value < min ? (min - value) : (value - max);
  final normalized = (distance / outsideTolerance).clamp(0, 1);
  return 100 - (normalized * 100);
}

double _targetScore({
  required double value,
  required double target,
  required double tolerance,
}) {
  final distance = (value - target).abs();
  final normalized = (distance / tolerance).clamp(0, 1);
  return 100 - (normalized * 100);
}

class RecommendedSpeciesPanel extends StatelessWidget {
  final double temperature;
  final double humidity;

  const RecommendedSpeciesPanel({
    super.key,
    required this.temperature,
    required this.humidity,
  });

  @override
  Widget build(BuildContext context) {
    final ranked = rankSpecies(temperature: temperature, humidity: humidity);
    final best = ranked.first;
    final isIdeal = best.score >= 90;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: SizedBox(
                  height: 142,
                  width: double.infinity,
                  child: Image.asset(
                    'assets/forest.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF70A87D), Color(0xFF2D6C40)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.08),
                        Colors.black.withOpacity(0.28),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF188B43),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'PLANTA RECOMENDADA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E9146),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${best.score}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const Text(
                        'compat.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      best.species.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      best.species.scientificName,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.thermostat_rounded,
                  label: 'Faixa ideal:',
                  value: '${best.species.minTemp.toInt()}-${best.species.maxTemp.toInt()}°C',
                ),
                const SizedBox(height: 14),
                _InfoRow(
                  icon: Icons.water_drop_rounded,
                  label: 'Umidade:',
                  value: '~${best.species.targetHumidity.toInt()}%',
                ),
                const SizedBox(height: 14),
                Text(
                  _descriptionForSpecies(best.species.name),
                  style: const TextStyle(
                    color: Color(0xFF3F4B56),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: isIdeal ? const Color(0xFFD7F2DF) : const Color(0xFFFFF2D6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isIdeal ? Icons.check_circle_rounded : Icons.info_rounded,
                        color: isIdeal ? const Color(0xFF11813D) : const Color(0xFFBB7A00),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isIdeal
                              ? 'Condições dentro da faixa ideal'
                              : 'Espécie próxima das condições atuais',
                          style: TextStyle(
                            color: isIdeal ? const Color(0xFF11813D) : const Color(0xFF8C5A00),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          InkWell(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
            onTap: () => showSpeciesCompatibilitySheet(
              context,
              temperature: temperature,
              humidity: humidity,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Row(
                children: [
                  Text(
                    'Ver todas as espécies (${ranked.length})',
                    style: const TextStyle(
                      color: Color(0xFF11813D),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF11813D), size: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showSpeciesCompatibilitySheet(
  BuildContext context, {
  required double temperature,
  required double humidity,
}) {
  final ranked = rankSpecies(temperature: temperature, humidity: humidity);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.42,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF7F8FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 60,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3D8DE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                    children: [
                      const Text(
                        'Espécies por\ncompatibilidade',
                        style: TextStyle(
                          color: Color(0xFF0F2342),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Leitura atual: ${temperature.toStringAsFixed(1)}°C · ${humidity.toStringAsFixed(0)}% umidade',
                        style: const TextStyle(
                          color: Color(0xFF66758A),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(ranked.length, (index) {
                        final item = ranked[index];
                        return _SpeciesRankCard(
                          index: index + 1,
                          item: item,
                        );
                      }),
                      const SizedBox(height: 18),
                      const Text(
                        'Os dados do sensor são comparados com a tabela de espécies. Quando a leitura está fora de qualquer intervalo exato, a espécie mais próxima é indicada por aproximação (menor distância para a faixa de temperatura e umidade alvo).',
                        style: TextStyle(
                          color: Color(0xFF6D7681),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _SpeciesRankCard extends StatelessWidget {
  final int index;
  final SpeciesResult item;

  const _SpeciesRankCard({required this.index, required this.item});

  @override
  Widget build(BuildContext context) {
    final badgeColor = item.score >= 90
        ? const Color(0xFF189647)
        : item.score >= 70
            ? const Color(0xFFD88500)
            : const Color(0xFFE02424);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E5EA)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 60,
              height: 60,
              child: Image.asset(
                item.species.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFD9E8DB),
                  alignment: Alignment.center,
                  child: const Icon(Icons.park_rounded, color: Color(0xFF1F7A44)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#$index',
                      style: const TextStyle(
                        color: Color(0xFF7A8797),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.species.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1B2430),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (item.score >= 90)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.verified_rounded, size: 18, color: Color(0xFF169546)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.species.minTemp.toInt()}-${item.species.maxTemp.toInt()}°C · ${item.species.targetHumidity.toInt()}%',
                  style: const TextStyle(
                    color: Color(0xFF66758A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: item.score / 100,
                          backgroundColor: const Color(0xFFE2E6EB),
                          valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 70,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${item.score}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1E9146), size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF68717A),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1B2430),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

String _descriptionForSpecies(String name) {
  switch (name) {
    case 'Jacarandá da Bahia':
      return 'Mata Atlântica, climas quentes e úmidos.';
    case 'Jequitibá-rosa':
      return 'Árvore típica de florestas úmidas, com bom desempenho em ambientes amenos a quentes.';
    case 'Pau-Brasil / Guapuruvu':
      return 'Espécies adaptadas a ambientes quentes, com preferência por umidade moderada a alta.';
    case 'Pau-ferro':
      return 'Tolera variação de temperatura e se adapta bem a diferentes níveis de umidade.';
    case 'Araucária':
      return 'Prefere climas mais frios e umidade elevada.';
    case 'Ipê-amarelo':
      return 'Melhor em temperaturas mais baixas e ambientes menos úmidos.';
    case 'Angico':
      return 'Adapta-se melhor a clima quente e seco.';
    default:
      return 'Espécie comparada a partir da temperatura e da umidade lidas pelo sensor.';
  }
}

/*
COMO USAR:

1) Adicione este arquivo ao seu projeto Flutter.
2) Coloque suas imagens em assets/especies/ e registre no pubspec.yaml.
3) Onde quiser exibir o painel, use por exemplo:

RecommendedSpeciesPanel(
  temperature: 26.6,
  humidity: 77,
)

4) O botão "Ver todas as espécies" abre a lista ordenada automaticamente.
*/
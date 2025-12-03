import 'package:flutter/material.dart';
import '../models/work_center.dart';
import '../utils/constants.dart';

class TeamSelectionModal extends StatelessWidget {
  final List<WorkCenter> availableWorkCenters;
  final WorkCenter? currentWorkCenter;

  const TeamSelectionModal({
    super.key,
    required this.availableWorkCenters,
    this.currentWorkCenter,
  });

  @override
  Widget build(BuildContext context) {
    // Agrupar centros de trabajo por nombre de equipo
    final Map<String, List<WorkCenter>> groupedWorkCenters = {};
    for (var wc in availableWorkCenters) {
      final teamName = wc.teamName ?? 'Sin equipo';
      if (!groupedWorkCenters.containsKey(teamName)) {
        groupedWorkCenters[teamName] = [];
      }
      groupedWorkCenters[teamName]!.add(wc);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Seleccionar Equipo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(AppConstants.primaryColorValue),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: groupedWorkCenters.length,
              itemBuilder: (context, index) {
                final teamName = groupedWorkCenters.keys.elementAt(index);
                final centers = groupedWorkCenters[teamName]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Text(
                        teamName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    ...centers.map((wc) {
                      final isSelected = wc.code == currentWorkCenter?.code;
                      return InkWell(
                        onTap: () => Navigator.pop(context, wc),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          color: isSelected
                              ? const Color(AppConstants.primaryColorValue)
                                  .withOpacity(0.05)
                              : null,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(AppConstants.primaryColorValue)
                                      : Colors.grey[200],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.business,
                                  size: 20,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      wc.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? const Color(
                                                AppConstants.primaryColorValue)
                                            : Colors.black87,
                                      ),
                                    ),
                                    if (wc.code.isNotEmpty)
                                      Text(
                                        'Código: ${wc.code}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(AppConstants.primaryColorValue),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

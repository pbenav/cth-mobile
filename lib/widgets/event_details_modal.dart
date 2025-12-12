import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/history_event.dart';
import '../utils/constants.dart';
import '../i18n/i18n_service.dart';

class EventDetailsModal extends StatelessWidget {
  final HistoryEvent event;

  const EventDetailsModal({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(AppConstants.primaryColorValue),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      I18n.of('history.details.title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      context,
                      I18n.of('history.details.id'),
                      event.id.toString(),
                      icon: Icons.tag,
                    ),
                    
                    _buildDetailRow(
                      context,
                      I18n.of('history.details.type'),
                      event.type,
                      icon: Icons.category,
                    ),
                    
                    _buildDetailRow(
                      context,
                      I18n.of('history.details.event_type_id'),
                      event.eventTypeId.toString(),
                      icon: Icons.numbers,
                    ),
                    
                    if (event.teamName != null)
                      _buildDetailRow(
                        context,
                        I18n.of('history.details.team'),
                        event.teamName!,
                        icon: Icons.group,
                      ),
                    
                    if (event.workCenterName != null || event.workCenterCode != null)
                      _buildDetailRow(
                        context,
                        I18n.of('history.details.work_center'),
                        event.workCenterName ?? event.workCenterCode ?? 'N/A',
                        icon: Icons.business,
                      ),
                    
                    _buildDetailRow(
                      context,
                      I18n.of('history.details.status'),
                      event.isOpen 
                          ? I18n.of('history.status.open')
                          : I18n.of('history.status.closed'),
                      icon: event.isOpen ? Icons.lock_open : Icons.lock,
                      valueColor: event.isOpen ? Colors.green : Colors.grey,
                    ),
                    
                    if (event.start != null)
                      _buildDetailRow(
                        context,
                        I18n.of('history.details.start'),
                        _formatDateTime(event.start!),
                        icon: Icons.play_arrow,
                      ),
                    
                    if (event.end != null)
                      _buildDetailRow(
                        context,
                        I18n.of('history.details.end'),
                        _formatDateTime(event.end!),
                        icon: Icons.stop,
                      ),
                    
                    if (event.durationFormatted != null)
                      _buildDetailRow(
                        context,
                        I18n.of('history.details.duration'),
                        event.durationFormatted!,
                        icon: Icons.timer,
                      ),
                    
                    if (event.createdAt != null)
                      _buildDetailRow(
                        context,
                        I18n.of('history.details.created_at'),
                        _formatDateTime(event.createdAt!),
                        icon: Icons.access_time,
                      ),
                    
                    // Status badges
                    if (event.isAuthorized || event.isExceptional) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle(context, I18n.of('history.details.attributes')),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (event.isAuthorized)
                            _buildStatusChip(
                              I18n.of('history.status.authorized'),
                              Colors.blue,
                              Icons.check_circle,
                            ),
                          if (event.isExceptional)
                            _buildStatusChip(
                              I18n.of('history.status.exceptional'),
                              Colors.orange,
                              Icons.warning,
                            ),
                        ],
                      ),
                    ],
                    
                    // Observations
                    if (event.observations != null && event.observations!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle(context, I18n.of('history.details.observations')),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          event.observations!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                    ],
                    
                    // Description
                    if (event.description != null && event.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionTitle(context, I18n.of('history.details.description')),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Text(
                          event.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(I18n.of('common.close')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(AppConstants.primaryColorValue),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(dt.toLocal());
  }
}

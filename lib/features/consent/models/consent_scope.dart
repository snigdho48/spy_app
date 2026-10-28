class ConsentScope {
  const ConsentScope({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  static const consentVersion = '1.0.0';

  static const List<ConsentScope> all = [
    ConsentScope(
      id: 'call_log',
      label: 'Call log',
      description:
          'Incoming, outgoing, and missed calls with numbers and duration',
    ),
    ConsentScope(
      id: 'sms',
      label: 'SMS',
      description: 'Text message history (sender, body, time)',
    ),
    ConsentScope(
      id: 'contacts',
      label: 'Contacts',
      description: 'Address book names, phone numbers, and email addresses',
    ),
    ConsentScope(
      id: 'messaging',
      label: 'Messenger & WhatsApp',
      description:
          'Notification alerts from chat apps (title, preview text, app name)',
    ),
    ConsentScope(
      id: 'sim',
      label: 'SIM card',
      description: 'Active SIM phone number and insert/remove history',
    ),
    ConsentScope(
      id: 'location',
      label: 'Location',
      description: 'GPS and location updates',
    ),
    ConsentScope(
      id: 'battery',
      label: 'Battery',
      description: 'Battery level and charging status',
    ),
    ConsentScope(
      id: 'network',
      label: 'Network',
      description: 'Wi‑Fi and mobile connectivity',
    ),
    ConsentScope(
      id: 'app_usage',
      label: 'App usage',
      description: 'Which apps are used and for how long',
    ),
    ConsentScope(
      id: 'device_info',
      label: 'Device info',
      description: 'Model, OS version, and device identifiers',
    ),
    ConsentScope(
      id: 'notifications',
      label: 'Other notifications',
      description: 'General notification metadata from other apps',
    ),
    ConsentScope(
      id: 'screen',
      label: 'Live screen',
      description:
          'Lets the monitor view this device\'s screen live while enrolled. '
          'Android still shows the system screen-capture dialog when capture '
          'runs. Revoke anytime.',
    ),
  ];
}

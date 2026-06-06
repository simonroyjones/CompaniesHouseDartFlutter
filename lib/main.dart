import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const CompaniesHouseLookupApp());
}

class CompaniesHouseLookupApp extends StatelessWidget {
  const CompaniesHouseLookupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Companies House Lookup',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const CompaniesHouseLookupPage(),
    );
  }
}

enum SearchMode { company, officer }

class SearchPageResetNotifier extends ChangeNotifier {
  SearchPageResetNotifier._();

  static final SearchPageResetNotifier instance = SearchPageResetNotifier._();

  void resetToInitialSearch() {
    notifyListeners();
  }
}

class CompaniesHouseLookupPage extends StatefulWidget {
  const CompaniesHouseLookupPage({super.key});

  @override
  State<CompaniesHouseLookupPage> createState() =>
      _CompaniesHouseLookupPageState();
}

class _CompaniesHouseLookupPageState extends State<CompaniesHouseLookupPage> {
  final TextEditingController _searchController = TextEditingController();

  static const String _apiKey = String.fromEnvironment(
    'COMPANIES_HOUSE_API_KEY',
  );

  SearchMode _searchMode = SearchMode.company;

  bool _isLoading = false;
  String? _errorMessage;

  CompanyProfile? _companyProfile;
  List<CompanySearchResult> _searchResults = [];
  List<OfficerSearchResult> _officerSearchResults = [];

  @override
  void initState() {
    super.initState();
    SearchPageResetNotifier.instance.addListener(_resetSearchPage);
  }

  @override
  void dispose() {
    SearchPageResetNotifier.instance.removeListener(_resetSearchPage);
    _searchController.dispose();
    super.dispose();
  }

  void _resetSearchPage() {
    setState(() {
      _searchController.clear();
      _searchMode = SearchMode.company;
      _isLoading = false;
      _errorMessage = null;
      _companyProfile = null;
      _searchResults = [];
      _officerSearchResults = [];
    });
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _errorMessage = _searchMode == SearchMode.company
            ? 'Please enter a company number or company name.'
            : 'Please enter an officer name.';
        _companyProfile = null;
        _searchResults = [];
        _officerSearchResults = [];
      });
      return;
    }

    if (_apiKey.isEmpty) {
      setState(() {
        _errorMessage =
            'Missing Companies House API key. Run with '
            '--dart-define=COMPANIES_HOUSE_API_KEY=your_key.';
        _companyProfile = null;
        _searchResults = [];
        _officerSearchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _companyProfile = null;
      _searchResults = [];
      _officerSearchResults = [];
    });

    try {
      if (_searchMode == SearchMode.company) {
        if (_looksLikeCompanyNumber(query)) {
          final profile = await CompaniesHouseApi.getCompanyByNumber(
            apiKey: _apiKey,
            companyNumber: query,
          );

          setState(() {
            _companyProfile = profile;
          });

          return;
        }

        final results = await CompaniesHouseApi.searchCompaniesByName(
          apiKey: _apiKey,
          companyName: query,
        );

        setState(() {
          _searchResults = results;
        });
      } else {
        final results = await CompaniesHouseApi.searchOfficersByName(
          apiKey: _apiKey,
          officerName: query,
        );

        setState(() {
          _officerSearchResults = results;
        });
      }
    } on CompaniesHouseException catch (ex) {
      setState(() {
        _errorMessage = ex.message;
      });
    } catch (ex) {
      setState(() {
        _errorMessage = 'Unexpected error: $ex';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSelectedCompany(String companyNumber) async {
    if (_apiKey.isEmpty) {
      setState(() {
        _errorMessage =
            'Missing Companies House API key. Run with '
            '--dart-define=COMPANIES_HOUSE_API_KEY=your_key.';
        _companyProfile = null;
        _officerSearchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _companyProfile = null;
      _officerSearchResults = [];
    });

    try {
      final profile = await CompaniesHouseApi.getCompanyByNumber(
        apiKey: _apiKey,
        companyNumber: companyNumber,
      );

      setState(() {
        _companyProfile = profile;
      });
    } on CompaniesHouseException catch (ex) {
      setState(() {
        _errorMessage = ex.message;
      });
    } catch (ex) {
      setState(() {
        _errorMessage = 'Unexpected error: $ex';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _looksLikeCompanyNumber(String query) {
    return RegExp(r'^(?:[A-Za-z]{2}\d{6}|\d{8})$').hasMatch(query.trim());
  }

  String get _hintText {
    return _searchMode == SearchMode.company
        ? 'Enter a company name or number, e.g. Tesco or 00445790'
        : 'Enter an officer name, e.g. John Smith';
  }

  String get _titleText {
    return _searchMode == SearchMode.company
        ? 'Find a company'
        : 'Find an officer';
  }

  String get _emptyText {
    return _searchMode == SearchMode.company
        ? 'Enter a company number or company name to begin.'
        : 'Enter an officer name to begin.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f6fb),
      appBar: AppBar(
        title: const Text('Companies House Lookup'),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _titleText,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SegmentedButton<SearchMode>(
                          segments: const [
                            ButtonSegment(
                              value: SearchMode.company,
                              label: Text('Company'),
                              icon: Icon(Icons.business),
                            ),
                            ButtonSegment(
                              value: SearchMode.officer,
                              label: Text('Officer'),
                              icon: Icon(Icons.person_search),
                            ),
                          ],
                          selected: {_searchMode},
                          onSelectionChanged: (selected) {
                            setState(() {
                              _searchMode = selected.first;
                              _companyProfile = null;
                              _searchResults = [];
                              _officerSearchResults = [];
                              _errorMessage = null;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: _searchMode == SearchMode.company
                                ? 'Company name or number'
                                : 'Officer name',
                            hintText: _hintText,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.search),
                          ),
                          onSubmitted: (_) => _runSearch(),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _runSearch,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.search),
                          label: Text(_isLoading ? 'Searching...' : 'Search'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (_errorMessage != null)
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_companyProfile != null)
                  Expanded(
                    child: SingleChildScrollView(
                      child: CompanyProfileCard(
                        apiKey: _apiKey,
                        company: _companyProfile!,
                      ),
                    ),
                  )
                else if (_searchResults.isNotEmpty)
                  Expanded(
                    child: CompanySearchResultsList(
                      results: _searchResults,
                      onSelectCompany: _loadSelectedCompany,
                    ),
                  )
                else if (_officerSearchResults.isNotEmpty)
                  Expanded(
                    child: OfficerSearchResultsList(
                      apiKey: _apiKey,
                      results: _officerSearchResults,
                    ),
                  )
                else
                  Expanded(
                    child: Center(
                      child: Text(
                        _emptyText,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CompanySearchResultsList extends StatelessWidget {
  final List<CompanySearchResult> results;
  final Future<void> Function(String companyNumber) onSelectCompany;

  const CompanySearchResultsList({
    super.key,
    required this.results,
    required this.onSelectCompany,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: results.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = results[index];

          return ListTile(
            leading: const Icon(Icons.business),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                'Company number: ${item.companyNumber}',
                if (item.companyStatus != null) 'Status: ${item.companyStatus}',
                if (item.addressSnippet != null) item.addressSnippet!,
              ].join('\n'),
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onSelectCompany(item.companyNumber),
          );
        },
      ),
    );
  }
}

class OfficerSearchResultsList extends StatelessWidget {
  final String apiKey;
  final List<OfficerSearchResult> results;

  const OfficerSearchResultsList({
    super.key,
    required this.apiKey,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: results.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = results[index];

          return ListTile(
            leading: const Icon(Icons.person_search),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(item.summaryLines.join('\n')),
            isThreeLine: true,
            trailing: item.officerId == null
                ? null
                : const Icon(Icons.chevron_right),
            onTap: item.officerId == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => OfficerAppointmentsPage(
                          apiKey: apiKey,
                          officer: item.toCompanyOfficer(),
                        ),
                      ),
                    );
                  },
          );
        },
      ),
    );
  }
}

class CompanyProfileCard extends StatelessWidget {
  final String apiKey;
  final CompanyProfile company;

  const CompanyProfileCard({
    super.key,
    required this.apiKey,
    required this.company,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              company.companyName,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Company number: ${company.companyNumber}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                InfoChip(
                  label: 'Status',
                  value: company.companyStatus ?? 'Unknown',
                ),
                InfoChip(
                  label: 'Type',
                  value: company.companyType ?? 'Unknown',
                ),
                InfoChip(
                  label: 'Incorporated',
                  value: company.dateOfCreation ?? 'Unknown',
                ),
                InfoChip(
                  label: 'Jurisdiction',
                  value: company.jurisdiction ?? 'Unknown',
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Registered office address',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              company.registeredOfficeAddress ?? 'No address returned.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 22),
            const Text(
              'Accounts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(company.accountsSummary),
            const SizedBox(height: 22),
            const Text(
              'Confirmation statement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(company.confirmationStatementSummary),
            const SizedBox(height: 22),
            CompanyRelationshipsSection(apiKey: apiKey, company: company),
          ],
        ),
      ),
    );
  }
}

enum CompanyRelationshipView { officers, significantControl }

class CompanyRelationshipsSection extends StatefulWidget {
  final String apiKey;
  final CompanyProfile company;

  const CompanyRelationshipsSection({
    super.key,
    required this.apiKey,
    required this.company,
  });

  @override
  State<CompanyRelationshipsSection> createState() =>
      _CompanyRelationshipsSectionState();
}

class _CompanyRelationshipsSectionState
    extends State<CompanyRelationshipsSection> {
  CompanyRelationshipView _selectedView = CompanyRelationshipView.officers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<CompanyRelationshipView>(
          segments: [
            ButtonSegment(
              value: CompanyRelationshipView.officers,
              label: Text('Officers (${widget.company.officers.length})'),
              icon: const Icon(Icons.people),
            ),
            ButtonSegment(
              value: CompanyRelationshipView.significantControl,
              label: Text(
                'PSC (${widget.company.significantControllers.length})',
              ),
              icon: const Icon(Icons.verified_user),
            ),
          ],
          selected: {_selectedView},
          onSelectionChanged: (selected) {
            setState(() {
              _selectedView = selected.first;
            });
          },
        ),
        const SizedBox(height: 14),
        if (_selectedView == CompanyRelationshipView.officers)
          CompanyOfficersSection(
            apiKey: widget.apiKey,
            officers: widget.company.officers,
          )
        else
          SignificantControllersSection(
            significantControllers: widget.company.significantControllers,
          ),
      ],
    );
  }
}

class CompanyOfficersSection extends StatelessWidget {
  final String apiKey;
  final List<CompanyOfficer> officers;

  const CompanyOfficersSection({
    super.key,
    required this.apiKey,
    required this.officers,
  });

  @override
  Widget build(BuildContext context) {
    if (officers.isEmpty) {
      return const Text('No officers returned.');
    }

    return Column(
      children: officers
          .map((officer) => OfficerListItem(apiKey: apiKey, officer: officer))
          .toList(),
    );
  }
}

class SignificantControllersSection extends StatelessWidget {
  final List<SignificantController> significantControllers;

  const SignificantControllersSection({
    super.key,
    required this.significantControllers,
  });

  @override
  Widget build(BuildContext context) {
    if (significantControllers.isEmpty) {
      return const Text('No people with significant control returned.');
    }

    return Column(
      children: significantControllers
          .map((psc) => SignificantControllerListItem(psc: psc))
          .toList(),
    );
  }
}

class OfficerListItem extends StatelessWidget {
  final String apiKey;
  final CompanyOfficer officer;

  const OfficerListItem({
    super.key,
    required this.apiKey,
    required this.officer,
  });

  @override
  Widget build(BuildContext context) {
    final detailLines = [
      'Role: ${officer.role ?? 'Unknown'}',
      if (officer.appointedOn != null) 'Appointed: ${officer.appointedOn}',
      if (officer.resignedOn != null) 'Resigned: ${officer.resignedOn}',
      if (officer.dateOfBirth != null) 'Born: ${officer.dateOfBirth}',
      if (officer.occupation != null) 'Occupation: ${officer.occupation}',
      if (officer.nationality != null) 'Nationality: ${officer.nationality}',
      if (officer.countryOfResidence != null)
        'Residence: ${officer.countryOfResidence}',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: officer.resignedOn == null ? Colors.white : Colors.grey.shade100,
      child: ListTile(
        leading: Icon(
          officer.resignedOn == null ? Icons.person : Icons.person_off,
        ),
        title: Text(
          officer.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(detailLines.join('\n')),
        isThreeLine: true,
        trailing: officer.officerId == null
            ? null
            : const Icon(Icons.chevron_right),
        onTap: officer.officerId == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => OfficerAppointmentsPage(
                      apiKey: apiKey,
                      officer: officer,
                    ),
                  ),
                );
              },
      ),
    );
  }
}

class SignificantControllerListItem extends StatelessWidget {
  final SignificantController psc;

  const SignificantControllerListItem({super.key, required this.psc});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: psc.ceasedOn == null ? Colors.white : Colors.grey.shade100,
      child: ListTile(
        leading: Icon(
          psc.ceasedOn == null ? Icons.verified_user : Icons.person_off,
        ),
        title: Text(
          psc.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(psc.summaryLines.join('\n')),
        isThreeLine: true,
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const InfoChip({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      padding: const EdgeInsets.all(8),
    );
  }
}

class SearchHomeAction extends StatelessWidget {
  const SearchHomeAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back to search',
      icon: const Icon(Icons.manage_search),
      onPressed: () {
        SearchPageResetNotifier.instance.resetToInitialSearch();
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }
}

class OfficerAppointmentsPage extends StatefulWidget {
  final String apiKey;
  final CompanyOfficer officer;

  const OfficerAppointmentsPage({
    super.key,
    required this.apiKey,
    required this.officer,
  });

  @override
  State<OfficerAppointmentsPage> createState() =>
      _OfficerAppointmentsPageState();
}

class _OfficerAppointmentsPageState extends State<OfficerAppointmentsPage> {
  late final Future<List<OfficerAppointment>> _appointmentsFuture;

  @override
  void initState() {
    super.initState();
    _appointmentsFuture = CompaniesHouseApi.getOfficerAppointments(
      apiKey: widget.apiKey,
      officerId: widget.officer.officerId!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f6fb),
      appBar: AppBar(
        title: Text(widget.officer.name),
        actions: const [SearchHomeAction()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: FutureBuilder<List<OfficerAppointment>>(
            future: _appointmentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ErrorCard(message: snapshot.error.toString());
              }

              final appointments = snapshot.data ?? [];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              widget.officer.name,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              [
                                if (widget.officer.role != null)
                                  'Current role: ${widget.officer.role}',
                                if (widget.officer.dateOfBirth != null)
                                  'Born: ${widget.officer.dateOfBirth}',
                                if (widget.officer.nationality != null)
                                  'Nationality: ${widget.officer.nationality}',
                                if (widget.officer.countryOfResidence != null)
                                  'Residence: ${widget.officer.countryOfResidence}',
                              ].join('\n'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Directorships and appointments',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Chip(label: Text('${appointments.length} returned')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (appointments.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('No appointments returned.'),
                        ),
                      )
                    else
                      ...appointments.map(
                        (appointment) => OfficerAppointmentListItem(
                          apiKey: widget.apiKey,
                          appointment: appointment,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class OfficerAppointmentListItem extends StatelessWidget {
  final String apiKey;
  final OfficerAppointment appointment;

  const OfficerAppointmentListItem({
    super.key,
    required this.apiKey,
    required this.appointment,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: appointment.resignedOn == null
          ? Colors.white
          : Colors.grey.shade100,
      child: ListTile(
        leading: Icon(
          appointment.resignedOn == null
              ? Icons.business
              : Icons.business_center,
        ),
        title: Text(
          appointment.companyName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(appointment.summaryLines.join('\n')),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CompanyDetailPage(
                apiKey: apiKey,
                companyNumber: appointment.companyNumber,
              ),
            ),
          );
        },
      ),
    );
  }
}

class CompanyDetailPage extends StatelessWidget {
  final String apiKey;
  final String companyNumber;

  const CompanyDetailPage({
    super.key,
    required this.apiKey,
    required this.companyNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f6fb),
      appBar: AppBar(
        title: Text(companyNumber),
        actions: const [SearchHomeAction()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: FutureBuilder<CompanyProfile>(
            future: CompaniesHouseApi.getCompanyByNumber(
              apiKey: apiKey,
              companyNumber: companyNumber,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ErrorCard(message: snapshot.error.toString());
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: CompanyProfileCard(
                  apiKey: apiKey,
                  company: snapshot.data!,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  final String message;

  const ErrorCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompaniesHouseApi {
  static const String _baseUrl =
      'https://api.company-information.service.gov.uk';

  static Map<String, String> _headers(String apiKey) {
    final authValue = base64Encode(utf8.encode('$apiKey:'));

    return {'Authorization': 'Basic $authValue', 'Accept': 'application/json'};
  }

  static Future<CompanyProfile> getCompanyByNumber({
    required String apiKey,
    required String companyNumber,
  }) async {
    final cleanedCompanyNumber = companyNumber.trim();

    final uri = Uri.parse('$_baseUrl/company/$cleanedCompanyNumber');

    final response = await http.get(uri, headers: _headers(apiKey));

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      final extraData = await Future.wait([
        getCompanyOfficers(apiKey: apiKey, companyNumber: cleanedCompanyNumber),
        getSignificantControllers(
          apiKey: apiKey,
          companyNumber: cleanedCompanyNumber,
        ),
      ]);

      return CompanyProfile.fromJson(
        jsonMap,
        officers: extraData[0] as List<CompanyOfficer>,
        significantControllers: extraData[1] as List<SignificantController>,
      );
    }

    if (response.statusCode == 404) {
      throw CompaniesHouseException(
        'No company found with company number $cleanedCompanyNumber.',
      );
    }

    if (response.statusCode == 401) {
      throw CompaniesHouseException(
        'Authentication failed. Please check your Companies House API key.',
      );
    }

    throw CompaniesHouseException(
      'Companies House returned HTTP ${response.statusCode}.',
    );
  }

  static Future<List<CompanySearchResult>> searchCompaniesByName({
    required String apiKey,
    required String companyName,
  }) async {
    final uri = Uri.parse('$_baseUrl/search/companies').replace(
      queryParameters: {'q': companyName.trim(), 'items_per_page': '20'},
    );

    final response = await http.get(uri, headers: _headers(apiKey));

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      final items = jsonMap['items'] as List<dynamic>? ?? [];

      return items
          .map(
            (item) =>
                CompanySearchResult.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    if (response.statusCode == 401) {
      throw CompaniesHouseException(
        'Authentication failed. Please check your Companies House API key.',
      );
    }

    throw CompaniesHouseException(
      'Companies House returned HTTP ${response.statusCode}.',
    );
  }

  static Future<List<OfficerSearchResult>> searchOfficersByName({
    required String apiKey,
    required String officerName,
  }) async {
    final uri = Uri.parse('$_baseUrl/search/officers').replace(
      queryParameters: {'q': officerName.trim(), 'items_per_page': '20'},
    );

    final response = await http.get(uri, headers: _headers(apiKey));

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      final items = jsonMap['items'] as List<dynamic>? ?? [];

      return items
          .map(
            (item) =>
                OfficerSearchResult.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    if (response.statusCode == 401) {
      throw CompaniesHouseException(
        'Authentication failed. Please check your Companies House API key.',
      );
    }

    throw CompaniesHouseException(
      'Companies House officer search returned HTTP ${response.statusCode}.',
    );
  }

  static Future<List<CompanyOfficer>> getCompanyOfficers({
    required String apiKey,
    required String companyNumber,
  }) async {
    final cleanedCompanyNumber = companyNumber.trim();

    final uri = Uri.parse(
      '$_baseUrl/company/$cleanedCompanyNumber/officers',
    ).replace(queryParameters: {'items_per_page': '35'});

    final response = await http.get(uri, headers: _headers(apiKey));

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      final items = jsonMap['items'] as List<dynamic>? ?? [];

      return items
          .map((item) => CompanyOfficer.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    if (response.statusCode == 404) {
      return [];
    }

    if (response.statusCode == 401) {
      throw CompaniesHouseException(
        'Authentication failed. Please check your Companies House API key.',
      );
    }

    throw CompaniesHouseException(
      'Companies House officers endpoint returned HTTP ${response.statusCode}.',
    );
  }

  static Future<List<SignificantController>> getSignificantControllers({
    required String apiKey,
    required String companyNumber,
  }) async {
    final cleanedCompanyNumber = companyNumber.trim();

    final uri = Uri.parse(
      '$_baseUrl/company/$cleanedCompanyNumber/persons-with-significant-control',
    ).replace(queryParameters: {'items_per_page': '50'});

    final response = await http.get(uri, headers: _headers(apiKey));

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      final items = jsonMap['items'] as List<dynamic>? ?? [];

      return items
          .map(
            (item) =>
                SignificantController.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    if (response.statusCode == 404) {
      return [];
    }

    if (response.statusCode == 401) {
      throw CompaniesHouseException(
        'Authentication failed. Please check your Companies House API key.',
      );
    }

    throw CompaniesHouseException(
      'Companies House PSC endpoint returned HTTP ${response.statusCode}.',
    );
  }

  static Future<List<OfficerAppointment>> getOfficerAppointments({
    required String apiKey,
    required String officerId,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/officers/$officerId/appointments',
    ).replace(queryParameters: {'items_per_page': '50'});

    final response = await http.get(uri, headers: _headers(apiKey));

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      final items = jsonMap['items'] as List<dynamic>? ?? [];

      return items
          .map(
            (item) => OfficerAppointment.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    }

    if (response.statusCode == 401) {
      throw CompaniesHouseException(
        'Authentication failed. Please check your Companies House API key.',
      );
    }

    throw CompaniesHouseException(
      'Companies House appointments endpoint returned HTTP ${response.statusCode}.',
    );
  }
}

class CompanySearchResult {
  final String title;
  final String companyNumber;
  final String? companyStatus;
  final String? addressSnippet;

  CompanySearchResult({
    required this.title,
    required this.companyNumber,
    this.companyStatus,
    this.addressSnippet,
  });

  factory CompanySearchResult.fromJson(Map<String, dynamic> json) {
    return CompanySearchResult(
      title: json['title']?.toString() ?? 'Unknown company',
      companyNumber: json['company_number']?.toString() ?? '',
      companyStatus: json['company_status']?.toString(),
      addressSnippet: json['address_snippet']?.toString(),
    );
  }
}

class OfficerSearchResult {
  final String title;
  final String? description;
  final String? snippet;
  final String? addressSnippet;
  final int? appointmentCount;
  final String? dateOfBirth;
  final String? selfLink;

  OfficerSearchResult({
    required this.title,
    this.description,
    this.snippet,
    this.addressSnippet,
    this.appointmentCount,
    this.dateOfBirth,
    this.selfLink,
  });

  factory OfficerSearchResult.fromJson(Map<String, dynamic> json) {
    final dateOfBirth = json['date_of_birth'] as Map<String, dynamic>?;
    final links = json['links'] as Map<String, dynamic>?;

    return OfficerSearchResult(
      title: json['title']?.toString() ?? 'Unknown officer',
      description: json['description']?.toString(),
      snippet: json['snippet']?.toString(),
      addressSnippet: json['address_snippet']?.toString(),
      appointmentCount: int.tryParse(
        json['appointment_count']?.toString() ?? '',
      ),
      dateOfBirth: _formatDateOfBirth(dateOfBirth),
      selfLink: links?['self']?.toString(),
    );
  }

  List<String> get summaryLines {
    return [
      ?description,
      if (appointmentCount != null) 'Appointments: $appointmentCount',
      if (dateOfBirth != null) 'Born: $dateOfBirth',
      ?snippet,
      ?addressSnippet,
      if (selfLink != null) 'Officer record: $selfLink',
    ];
  }

  String? get officerId {
    if (selfLink == null) {
      return null;
    }

    final match = RegExp(
      r'^/officers/([^/]+)/appointments$',
    ).firstMatch(selfLink!);

    return match?.group(1);
  }

  CompanyOfficer toCompanyOfficer() {
    return CompanyOfficer(
      name: title,
      officerId: officerId,
      dateOfBirth: dateOfBirth,
    );
  }

  static String? _formatDateOfBirth(Map<String, dynamic>? dateOfBirth) {
    if (dateOfBirth == null) {
      return null;
    }

    final month = dateOfBirth['month']?.toString();
    final year = dateOfBirth['year']?.toString();

    if (month == null || year == null) {
      return null;
    }

    return '$month/$year';
  }
}

class CompanyProfile {
  final String companyName;
  final String companyNumber;
  final String? companyStatus;
  final String? companyType;
  final String? dateOfCreation;
  final String? jurisdiction;
  final String? registeredOfficeAddress;
  final String accountsSummary;
  final String confirmationStatementSummary;
  final List<SignificantController> significantControllers;
  final List<CompanyOfficer> officers;

  CompanyProfile({
    required this.companyName,
    required this.companyNumber,
    this.companyStatus,
    this.companyType,
    this.dateOfCreation,
    this.jurisdiction,
    this.registeredOfficeAddress,
    required this.accountsSummary,
    required this.confirmationStatementSummary,
    required this.significantControllers,
    required this.officers,
  });

  factory CompanyProfile.fromJson(
    Map<String, dynamic> json, {
    required List<CompanyOfficer> officers,
    required List<SignificantController> significantControllers,
  }) {
    final registeredOffice =
        json['registered_office_address'] as Map<String, dynamic>?;

    final accounts = json['accounts'] as Map<String, dynamic>?;
    final nextAccounts = accounts?['next_accounts'] as Map<String, dynamic>?;
    final lastAccounts = accounts?['last_accounts'] as Map<String, dynamic>?;

    final confirmationStatement =
        json['confirmation_statement'] as Map<String, dynamic>?;

    return CompanyProfile(
      companyName: json['company_name']?.toString() ?? 'Unknown company',
      companyNumber: json['company_number']?.toString() ?? '',
      companyStatus: json['company_status']?.toString(),
      companyType: json['type']?.toString(),
      dateOfCreation: json['date_of_creation']?.toString(),
      jurisdiction: json['jurisdiction']?.toString(),
      registeredOfficeAddress: _formatAddress(registeredOffice),
      accountsSummary: _formatAccounts(nextAccounts, lastAccounts),
      confirmationStatementSummary: _formatConfirmationStatement(
        confirmationStatement,
      ),
      significantControllers: significantControllers,
      officers: officers,
    );
  }

  static String? _formatAddress(Map<String, dynamic>? address) {
    if (address == null) {
      return null;
    }

    final parts =
        [
              address['premises'],
              address['address_line_1'],
              address['address_line_2'],
              address['locality'],
              address['region'],
              address['postal_code'],
              address['country'],
            ]
            .where((part) => part != null && part.toString().trim().isNotEmpty)
            .map((part) => part.toString())
            .toList();

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(', ');
  }

  static String _formatAccounts(
    Map<String, dynamic>? nextAccounts,
    Map<String, dynamic>? lastAccounts,
  ) {
    final nextDue = nextAccounts?['due_on']?.toString();
    final nextPeriodEnd = nextAccounts?['period_end_on']?.toString();
    final lastMadeUpTo = lastAccounts?['made_up_to']?.toString();

    final lines = <String>[];

    if (nextDue != null) {
      lines.add('Next accounts due: $nextDue');
    }

    if (nextPeriodEnd != null) {
      lines.add('Next accounts period end: $nextPeriodEnd');
    }

    if (lastMadeUpTo != null) {
      lines.add('Last accounts made up to: $lastMadeUpTo');
    }

    if (lines.isEmpty) {
      return 'No accounts information returned.';
    }

    return lines.join('\n');
  }

  static String _formatConfirmationStatement(
    Map<String, dynamic>? confirmationStatement,
  ) {
    if (confirmationStatement == null) {
      return 'No confirmation statement information returned.';
    }

    final nextDue = confirmationStatement['next_due']?.toString();
    final lastMadeUpTo = confirmationStatement['last_made_up_to']?.toString();

    final lines = <String>[];

    if (nextDue != null) {
      lines.add('Next statement due: $nextDue');
    }

    if (lastMadeUpTo != null) {
      lines.add('Last statement made up to: $lastMadeUpTo');
    }

    if (lines.isEmpty) {
      return 'No confirmation statement dates returned.';
    }

    return lines.join('\n');
  }
}

class CompanyOfficer {
  final String name;
  final String? officerId;
  final String? role;
  final String? appointedOn;
  final String? resignedOn;
  final String? nationality;
  final String? occupation;
  final String? countryOfResidence;
  final String? dateOfBirth;

  CompanyOfficer({
    required this.name,
    this.officerId,
    this.role,
    this.appointedOn,
    this.resignedOn,
    this.nationality,
    this.occupation,
    this.countryOfResidence,
    this.dateOfBirth,
  });

  factory CompanyOfficer.fromJson(Map<String, dynamic> json) {
    final dateOfBirth = json['date_of_birth'] as Map<String, dynamic>?;
    final links = json['links'] as Map<String, dynamic>?;
    final officerLinks = links?['officer'] as Map<String, dynamic>?;

    return CompanyOfficer(
      name: json['name']?.toString() ?? 'Unknown officer',
      officerId: _officerIdFromAppointmentsLink(
        officerLinks?['appointments']?.toString(),
      ),
      role: json['officer_role']?.toString(),
      appointedOn: json['appointed_on']?.toString(),
      resignedOn: json['resigned_on']?.toString(),
      nationality: json['nationality']?.toString(),
      occupation: json['occupation']?.toString(),
      countryOfResidence: json['country_of_residence']?.toString(),
      dateOfBirth: _formatDateOfBirth(dateOfBirth),
    );
  }

  static String? _formatDateOfBirth(Map<String, dynamic>? dateOfBirth) {
    if (dateOfBirth == null) {
      return null;
    }

    final month = dateOfBirth['month']?.toString();
    final year = dateOfBirth['year']?.toString();

    if (month == null || year == null) {
      return null;
    }

    return '$month/$year';
  }

  static String? _officerIdFromAppointmentsLink(String? appointmentsLink) {
    if (appointmentsLink == null) {
      return null;
    }

    final match = RegExp(
      r'^/officers/([^/]+)/appointments$',
    ).firstMatch(appointmentsLink);

    return match?.group(1);
  }
}

class SignificantController {
  final String name;
  final String? kind;
  final String? notifiedOn;
  final String? ceasedOn;
  final String? dateOfBirth;
  final String? nationality;
  final String? countryOfResidence;
  final String? address;
  final List<String> naturesOfControl;

  SignificantController({
    required this.name,
    this.kind,
    this.notifiedOn,
    this.ceasedOn,
    this.dateOfBirth,
    this.nationality,
    this.countryOfResidence,
    this.address,
    required this.naturesOfControl,
  });

  factory SignificantController.fromJson(Map<String, dynamic> json) {
    final dateOfBirth = json['date_of_birth'] as Map<String, dynamic>?;
    final address = json['address'] as Map<String, dynamic>?;
    final natures = json['natures_of_control'] as List<dynamic>? ?? [];

    return SignificantController(
      name: json['name']?.toString() ?? 'Unknown PSC',
      kind: json['kind']?.toString(),
      notifiedOn: json['notified_on']?.toString(),
      ceasedOn: json['ceased_on']?.toString(),
      dateOfBirth: _formatDateOfBirth(dateOfBirth),
      nationality: json['nationality']?.toString(),
      countryOfResidence: json['country_of_residence']?.toString(),
      address: _formatAddress(address),
      naturesOfControl: natures
          .map((nature) => _formatNatureOfControl(nature.toString()))
          .toList(),
    );
  }

  List<String> get summaryLines {
    return [
      if (kind != null) 'Type: ${_formatKind(kind!)}',
      if (notifiedOn != null) 'Notified: $notifiedOn',
      if (ceasedOn != null) 'Ceased: $ceasedOn',
      if (dateOfBirth != null) 'Born: $dateOfBirth',
      if (nationality != null) 'Nationality: $nationality',
      if (countryOfResidence != null) 'Residence: $countryOfResidence',
      ?address,
      if (naturesOfControl.isNotEmpty)
        'Control: ${naturesOfControl.join(', ')}',
    ];
  }

  static String? _formatDateOfBirth(Map<String, dynamic>? dateOfBirth) {
    if (dateOfBirth == null) {
      return null;
    }

    final month = dateOfBirth['month']?.toString();
    final year = dateOfBirth['year']?.toString();

    if (month == null || year == null) {
      return null;
    }

    return '$month/$year';
  }

  static String? _formatAddress(Map<String, dynamic>? address) {
    if (address == null) {
      return null;
    }

    final parts =
        [
              address['premises'],
              address['address_line_1'],
              address['address_line_2'],
              address['locality'],
              address['region'],
              address['postal_code'],
              address['country'],
            ]
            .where((part) => part != null && part.toString().trim().isNotEmpty)
            .map((part) => part.toString())
            .toList();

    return parts.isEmpty ? null : parts.join(', ');
  }

  static String _formatKind(String kind) {
    return kind
        .replaceAll('-', ' ')
        .replaceAll('psc', 'PSC')
        .replaceAll('with significant control', 'with significant control');
  }

  static String _formatNatureOfControl(String nature) {
    return nature
        .replaceAll('-', ' ')
        .replaceAll('ownership of shares', 'shares')
        .replaceAll('voting rights', 'voting rights')
        .replaceAll(
          'right to appoint and remove directors',
          'appoint/remove directors',
        )
        .replaceAll(
          'significant influence or control',
          'significant influence/control',
        );
  }
}

class OfficerAppointment {
  final String companyName;
  final String companyNumber;
  final String? companyStatus;
  final String? role;
  final String? appointedOn;
  final String? resignedOn;
  final String? occupation;
  final String? countryOfResidence;

  OfficerAppointment({
    required this.companyName,
    required this.companyNumber,
    this.companyStatus,
    this.role,
    this.appointedOn,
    this.resignedOn,
    this.occupation,
    this.countryOfResidence,
  });

  factory OfficerAppointment.fromJson(Map<String, dynamic> json) {
    final appointedTo = json['appointed_to'] as Map<String, dynamic>? ?? {};

    return OfficerAppointment(
      companyName: appointedTo['company_name']?.toString() ?? 'Unknown company',
      companyNumber: appointedTo['company_number']?.toString() ?? '',
      companyStatus: appointedTo['company_status']?.toString(),
      role: json['officer_role']?.toString(),
      appointedOn: json['appointed_on']?.toString(),
      resignedOn: json['resigned_on']?.toString(),
      occupation: json['occupation']?.toString(),
      countryOfResidence: json['country_of_residence']?.toString(),
    );
  }

  List<String> get summaryLines {
    return [
      'Company number: $companyNumber',
      if (companyStatus != null) 'Status: $companyStatus',
      if (role != null) 'Role: $role',
      if (appointedOn != null) 'Appointed: $appointedOn',
      if (resignedOn != null) 'Resigned: $resignedOn',
      if (occupation != null) 'Occupation: $occupation',
      if (countryOfResidence != null) 'Residence: $countryOfResidence',
    ];
  }
}

class CompaniesHouseException implements Exception {
  final String message;

  CompaniesHouseException(this.message);

  @override
  String toString() => message;
}

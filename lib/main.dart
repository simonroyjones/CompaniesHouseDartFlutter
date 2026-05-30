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
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const CompaniesHouseLookupPage(),
    );
  }
}

enum SearchMode {
  companyNumber,
  companyName,
}

class CompaniesHouseLookupPage extends StatefulWidget {
  const CompaniesHouseLookupPage({super.key});

  @override
  State<CompaniesHouseLookupPage> createState() =>
      _CompaniesHouseLookupPageState();
}

class _CompaniesHouseLookupPageState extends State<CompaniesHouseLookupPage> {
  final TextEditingController _searchController = TextEditingController();

  // For prototype only.
  // Replace this with your new Companies House API key.
  final String _apiKey = '996b52d5-987b-4c15-a8cc-21242b8fc9c7';

  SearchMode _searchMode = SearchMode.companyNumber;

  bool _isLoading = false;
  String? _errorMessage;

  CompanyProfile? _companyProfile;
  List<CompanySearchResult> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a company number or company name.';
        _companyProfile = null;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _companyProfile = null;
      _searchResults = [];
    });

    try {
      if (_searchMode == SearchMode.companyNumber) {
        final profile = await CompaniesHouseApi.getCompanyByNumber(
          apiKey: _apiKey,
          companyNumber: query,
        );

        setState(() {
          _companyProfile = profile;
        });
      } else {
        final results = await CompaniesHouseApi.searchCompaniesByName(
          apiKey: _apiKey,
          companyName: query,
        );

        setState(() {
          _searchResults = results;
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _companyProfile = null;
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

  String get _hintText {
    return _searchMode == SearchMode.companyNumber
        ? 'Enter company number, e.g. 00445790'
        : 'Enter company name, e.g. Tesco';
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
                        const Text(
                          'Find a company',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SegmentedButton<SearchMode>(
                          segments: const [
                            ButtonSegment(
                              value: SearchMode.companyNumber,
                              label: Text('Company number'),
                              icon: Icon(Icons.numbers),
                            ),
                            ButtonSegment(
                              value: SearchMode.companyName,
                              label: Text('Company name'),
                              icon: Icon(Icons.business),
                            ),
                          ],
                          selected: {_searchMode},
                          onSelectionChanged: (selected) {
                            setState(() {
                              _searchMode = selected.first;
                              _companyProfile = null;
                              _searchResults = [];
                              _errorMessage = null;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: _searchMode == SearchMode.companyNumber
                                ? 'Company number'
                                : 'Company name',
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
                      child: CompanyProfileCard(company: _companyProfile!),
                    ),
                  )
                else if (_searchResults.isNotEmpty)
                  Expanded(
                    child: CompanySearchResultsList(
                      results: _searchResults,
                      onSelectCompany: _loadSelectedCompany,
                    ),
                  )
                else
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Enter a company number or company name to begin.',
                        style: TextStyle(color: Colors.black54),
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
        separatorBuilder: (_, __) => const Divider(height: 1),
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
                if (item.companyStatus != null)
                  'Status: ${item.companyStatus}',
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

class CompanyProfileCard extends StatelessWidget {
  final CompanyProfile company;

  const CompanyProfileCard({
    super.key,
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
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              company.registeredOfficeAddress ?? 'No address returned.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 22),
            const Text(
              'Accounts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(company.accountsSummary),
            const SizedBox(height: 22),
            const Text(
              'Confirmation statement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(company.confirmationStatementSummary),
          ],
        ),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const InfoChip({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      padding: const EdgeInsets.all(8),
    );
  }
}

class CompaniesHouseApi {
  static const String _baseUrl =
      'https://api.company-information.service.gov.uk';

  static Map<String, String> _headers(String apiKey) {
    final authValue = base64Encode(utf8.encode('$apiKey:'));

    return {
      'Authorization': 'Basic $authValue',
      'Accept': 'application/json',
    };
  }

  static Future<CompanyProfile> getCompanyByNumber({
    required String apiKey,
    required String companyNumber,
  }) async {
    final cleanedCompanyNumber = companyNumber.trim();

    final uri = Uri.parse('$_baseUrl/company/$cleanedCompanyNumber');

    final response = await http.get(
      uri,
      headers: _headers(apiKey),
    );

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      return CompanyProfile.fromJson(jsonMap);
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
      queryParameters: {
        'q': companyName.trim(),
        'items_per_page': '20',
      },
    );

    final response = await http.get(
      uri,
      headers: _headers(apiKey),
    );

    if (response.statusCode == 200) {
      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      final items = jsonMap['items'] as List<dynamic>? ?? [];

      return items
          .map(
            (item) => CompanySearchResult.fromJson(
          item as Map<String, dynamic>,
        ),
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
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> json) {
    final registeredOffice = json['registered_office_address']
    as Map<String, dynamic>?;

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
      confirmationStatementSummary:
      _formatConfirmationStatement(confirmationStatement),
    );
  }

  static String? _formatAddress(Map<String, dynamic>? address) {
    if (address == null) {
      return null;
    }

    final parts = [
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

class CompaniesHouseException implements Exception {
  final String message;

  CompaniesHouseException(this.message);

  @override
  String toString() => message;
}
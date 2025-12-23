import 'package:flutter/material.dart';

/// End User License Agreement (EULA) page
class EulaPage extends StatelessWidget {
  const EulaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('License Agreement'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTitle('END USER LICENSE AGREEMENT'),
          const SizedBox(height: 8),
          _buildSubtitle('QUDRIS SHOPKEEPER SOFTWARE'),
          const SizedBox(height: 24),

          _buildLastUpdated('Last Updated: January 2025'),
          const SizedBox(height: 24),

          _buildImportantNotice(),
          const SizedBox(height: 32),

          _buildSection(
            '1. DEFINITIONS',
            '''
1.1 "Agreement" means this End User License Agreement, including all schedules and appendices attached hereto.

1.2 "Application" or "Software" means Qudris ShopKeeper, including all updates, modifications, enhancements, and documentation provided by Qudris.

1.3 "License" means the limited, non-exclusive, non-transferable right to use the Software as set forth in this Agreement.

1.4 "Licensee," "You," or "User" means any individual or legal entity that downloads, installs, accesses, or uses the Software.

1.5 "Qudris," "We," "Us," or "Our" means Qudris Integral CNC, the owner and licensor of the Software.

1.6 "Personal Data" means any information relating to an identified or identifiable natural person processed through the Software.

1.7 "Services" means all features, functionalities, and services provided through the Software, including but not limited to inventory management, point of sale operations, reporting, and data synchronization.

1.8 "Intellectual Property Rights" means all patents, trademarks, service marks, trade names, copyrights, trade secrets, database rights, design rights, and other intellectual property rights, whether registered or unregistered, and all applications and rights to apply for any of the foregoing.''',
          ),

          _buildSection(
            '2. LICENSE GRANT',
            '''
2.1 GRANT OF LICENSE
Subject to your compliance with the terms and conditions of this Agreement, Qudris hereby grants you a limited, non-exclusive, non-transferable, revocable license to:

(a) Download, install, and use the Software on devices you own or control;
(b) Access and use the Services for your internal business purposes;
(c) Create and maintain data within the Software in accordance with this Agreement.

2.2 LICENSE SCOPE
The license granted herein is for the current version of the Software and includes all updates and upgrades that Qudris may make available to you during the term of your license. This license is granted on a per-user or per-device basis, as specified in your subscription or purchase agreement.

2.3 TERRITORY
Unless otherwise specified, this license is granted for worldwide use, subject to compliance with applicable local laws and regulations.

2.4 SUBSCRIPTION MODEL
Certain features of the Software may require an active subscription. Your access to such features is contingent upon maintaining a valid, paid subscription in good standing.''',
          ),

          _buildSection(
            '3. RESTRICTIONS AND PROHIBITED USES',
            '''
3.1 YOU SHALL NOT:
(a) Copy, modify, adapt, translate, reverse engineer, decompile, disassemble, or create derivative works based on the Software, except as expressly permitted by applicable law;

(b) Distribute, sublicense, lease, rent, loan, or otherwise transfer the Software or any portion thereof to any third party;

(c) Remove, alter, or obscure any copyright, trademark, or other proprietary rights notices contained in or on the Software;

(d) Use the Software for any illegal, fraudulent, or unauthorized purpose, or in any manner that violates any applicable laws, regulations, or third-party rights;

(e) Attempt to gain unauthorized access to the Software, Services, or any related systems or networks;

(f) Use the Software to transmit any viruses, malware, or other malicious code;

(g) Interfere with or disrupt the integrity or performance of the Software or the data contained therein;

(h) Use automated means (including bots, scrapers, or robots) to access or use the Software without our express written permission;

(i) Bypass, circumvent, or attempt to bypass or circumvent any security measures, access controls, or use limitations built into the Software;

(j) Use the Software to compete with Qudris or to develop competing products or services.

3.2 COMMERCIAL USE
The Software is licensed for use in connection with your lawful business operations. Any use that involves illegal activities, including but not limited to money laundering, tax evasion, or fraud, is strictly prohibited and shall constitute a material breach of this Agreement.

3.3 MULTI-TENANCY RESTRICTIONS
Unless you have obtained a separate enterprise license, you may not use the Software to provide services to multiple unrelated business entities or to operate as a service bureau.''',
          ),

          _buildSection(
            '4. INTELLECTUAL PROPERTY RIGHTS',
            '''
4.1 OWNERSHIP
The Software, including all source code, object code, documentation, interfaces, graphics, content, and all Intellectual Property Rights therein, is and shall remain the exclusive property of Qudris and its licensors. This Agreement does not convey to you any ownership rights in the Software, but only a limited right of use in accordance with the terms herein.

4.2 TRADEMARKS
"Qudris," "Qudris ShopKeeper," and all related logos, product names, and service names are trademarks or registered trademarks of Qudris Integral CNC. You may not use any of these marks without our prior written permission.

4.3 FEEDBACK AND SUGGESTIONS
If you provide Qudris with any feedback, suggestions, or ideas regarding the Software ("Feedback"), you hereby assign to Qudris all right, title, and interest in such Feedback. Qudris shall be free to use, implement, and exploit such Feedback without any obligation to you.

4.4 USER DATA
You retain all right, title, and interest in and to the data you create, upload, or input into the Software ("User Data"). By using the Software, you grant Qudris a worldwide, non-exclusive, royalty-free license to use, process, and store your User Data solely to the extent necessary to provide the Services and as described in Section 5 (Data Usage and Privacy).

4.5 OPEN SOURCE COMPONENTS
The Software may include certain open-source software components. Such components are licensed under their respective open-source licenses, which are made available to you. In the event of a conflict between this Agreement and any open-source license, the terms of the open-source license shall prevail with respect to that component only.''',
          ),

          _buildSection(
            '5. DATA USAGE AND PRIVACY',
            '''
5.1 DATA COLLECTION AND USE
By using Qudris ShopKeeper, you acknowledge and agree that Qudris collects, processes, and stores certain information to provide and improve the Services. This includes:

(a) Account information (name, email, phone number);
(b) Business information (shop name, location, currency preferences);
(c) Transaction data (sales records, inventory movements, product information);
(d) Usage data (feature usage, access logs, device information);
(e) Performance data (error logs, crash reports, analytics).

5.2 ANONYMIZED AND AGGREGATED DATA
By using Qudris ShopKeeper, you grant Qudris the right to use anonymized and aggregated data generated within the app to improve the application and enhance the user experience. This data cannot be used to identify you or your specific business and may include:

(a) Aggregated usage statistics and patterns;
(b) Feature adoption and engagement metrics;
(c) Performance benchmarks and optimization data;
(d) Anonymized transaction patterns and business trends.

5.3 DATA SECURITY
Qudris implements industry-standard security measures to protect your data, including:

(a) Encryption of data in transit using TLS/SSL protocols;
(b) Encryption of sensitive data at rest;
(c) Regular security audits and vulnerability assessments;
(d) Access controls and authentication mechanisms;
(e) Backup and disaster recovery procedures.

5.4 DATA RETENTION
Your User Data is retained for as long as your account remains active and for a reasonable period thereafter as required for legal, accounting, or business purposes. You may request deletion of your data by contacting us at support@qudris.com.

5.5 DATA LOCATION
Your data may be stored and processed in multiple jurisdictions, including but not limited to servers located in the United States, Europe, and Africa. By using the Software, you consent to the transfer and processing of your data in these jurisdictions.

5.6 THIRD-PARTY SERVICES
The Software may integrate with third-party services (e.g., payment processors, cloud storage providers). Your use of such services is subject to their respective terms and privacy policies. Qudris is not responsible for the practices of third-party service providers.

5.7 COMPLIANCE WITH PRIVACY LAWS
Qudris is committed to complying with applicable data protection laws, including but not limited to the Nigeria Data Protection Regulation (NDPR), the General Data Protection Regulation (GDPR) where applicable, and other relevant privacy legislation. For detailed information on how we collect, use, and protect your data, please refer to our Privacy Policy available at www.qudris.com/privacy.''',
          ),

          _buildSection(
            '6. WARRANTIES AND DISCLAIMERS',
            '''
6.1 LIMITED WARRANTY
Qudris warrants that the Software will perform substantially in accordance with its documentation under normal use. This warranty is valid for ninety (90) days from the date of initial download or installation. Your sole remedy for breach of this warranty is, at Qudris's option, repair or replacement of the Software, or refund of the fees paid for the Software.

6.2 DISCLAIMER OF WARRANTIES
EXCEPT AS EXPRESSLY PROVIDED IN SECTION 6.1, THE SOFTWARE IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTY OF ANY KIND. TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, QUDRIS DISCLAIMS ALL WARRANTIES, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED TO:

(a) IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT;
(b) WARRANTIES THAT THE SOFTWARE WILL BE UNINTERRUPTED, ERROR-FREE, OR COMPLETELY SECURE;
(c) WARRANTIES REGARDING THE ACCURACY, RELIABILITY, OR COMPLETENESS OF ANY CONTENT OR DATA PROVIDED THROUGH THE SOFTWARE;
(d) WARRANTIES THAT DEFECTS WILL BE CORRECTED OR THAT THE SOFTWARE IS FREE OF VIRUSES OR OTHER HARMFUL COMPONENTS.

6.3 NO GUARANTEE OF RESULTS
Qudris does not warrant or guarantee that the use of the Software will result in any particular business outcomes, including but not limited to increased sales, improved efficiency, or cost savings.

6.4 THIRD-PARTY CONTENT
The Software may provide access to third-party content, services, or websites. Qudris does not endorse, warrant, or assume responsibility for any third-party content or services.

6.5 REGULATORY COMPLIANCE
While the Software is designed to assist with business operations, you are solely responsible for ensuring that your use of the Software complies with all applicable laws, regulations, and industry standards, including but not limited to tax laws, accounting standards, and data protection regulations.''',
          ),

          _buildSection(
            '7. LIMITATION OF LIABILITY',
            '''
7.1 EXCLUSION OF DAMAGES
TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT SHALL QUDRIS, ITS AFFILIATES, OFFICERS, DIRECTORS, EMPLOYEES, AGENTS, OR LICENSORS BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING BUT NOT LIMITED TO:

(a) LOSS OF PROFITS, REVENUE, OR BUSINESS OPPORTUNITIES;
(b) LOSS OF DATA OR INFORMATION;
(c) BUSINESS INTERRUPTION;
(d) LOSS OF GOODWILL OR REPUTATION;
(e) COST OF SUBSTITUTE PRODUCTS OR SERVICES;
(f) DAMAGES RESULTING FROM UNAUTHORIZED ACCESS TO OR ALTERATION OF YOUR TRANSMISSIONS OR DATA;

ARISING OUT OF OR IN CONNECTION WITH THIS AGREEMENT OR YOUR USE OF OR INABILITY TO USE THE SOFTWARE, WHETHER BASED ON WARRANTY, CONTRACT, TORT (INCLUDING NEGLIGENCE), STATUTE, OR ANY OTHER LEGAL THEORY, EVEN IF QUDRIS HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

7.2 LIMITATION OF LIABILITY CAP
TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, QUDRIS'S TOTAL AGGREGATE LIABILITY ARISING OUT OF OR RELATED TO THIS AGREEMENT OR YOUR USE OF THE SOFTWARE SHALL NOT EXCEED THE GREATER OF:

(a) THE AMOUNT YOU PAID TO QUDRIS FOR THE SOFTWARE IN THE TWELVE (12) MONTHS IMMEDIATELY PRECEDING THE EVENT GIVING RISE TO THE LIABILITY; OR
(b) ONE HUNDRED US DOLLARS (USD \$100).

7.3 BASIS OF THE BARGAIN
You acknowledge and agree that the limitations of liability set forth in this Section 7 are fundamental elements of the basis of the bargain between you and Qudris, and that Qudris would not be able to provide the Software on an economically reasonable basis without such limitations.

7.4 APPLICABLE LAW
Some jurisdictions do not allow the exclusion or limitation of incidental or consequential damages, so the above limitations may not apply to you. In such jurisdictions, Qudris's liability shall be limited to the greatest extent permitted by law.''',
          ),

          _buildSection(
            '8. INDEMNIFICATION',
            '''
8.1 YOUR INDEMNIFICATION OBLIGATIONS
You agree to indemnify, defend, and hold harmless Qudris, its affiliates, and their respective officers, directors, employees, agents, and licensors from and against any and all claims, liabilities, damages, losses, costs, expenses, or fees (including reasonable attorneys' fees) arising out of or relating to:

(a) Your violation of this Agreement or any applicable law or regulation;
(b) Your violation of any third-party rights, including intellectual property rights or privacy rights;
(c) Your use or misuse of the Software;
(d) Your User Data or any content you submit, post, or transmit through the Software;
(e) Any negligent or wrongful conduct by you or any person using your account.

8.2 DEFENSE AND SETTLEMENT
Qudris reserves the right to assume the exclusive defense and control of any matter subject to indemnification by you, and you agree to cooperate with our defense of such claims. You agree not to settle any such claim without Qudris's prior written consent.''',
          ),

          _buildSection(
            '9. TERM AND TERMINATION',
            '''
9.1 TERM
This Agreement is effective from the date you first download, install, or use the Software and shall continue until terminated in accordance with this Section 9.

9.2 TERMINATION BY YOU
You may terminate this Agreement at any time by:
(a) Ceasing all use of the Software;
(b) Uninstalling the Software from all devices; and
(c) Notifying Qudris of your termination by email at support@qudris.com.

9.3 TERMINATION BY QUDRIS
Qudris may terminate this Agreement and your license to use the Software immediately and without notice if:

(a) You breach any provision of this Agreement;
(b) You fail to pay any fees when due (if applicable);
(c) Your use of the Software poses a security risk or violates applicable laws;
(d) Qudris is required to do so by law or governmental authority;
(e) Qudris decides to discontinue the Software or certain features thereof.

9.4 EFFECT OF TERMINATION
Upon termination of this Agreement:

(a) Your license to use the Software immediately ceases;
(b) You must cease all use of the Software and destroy all copies in your possession or control;
(c) Qudris may delete your User Data in accordance with our data retention policies;
(d) Sections 3, 4, 5.2, 6.2-6.5, 7, 8, 9.4, 10, and 11 shall survive termination.

9.5 NO REFUNDS
Unless otherwise required by applicable law, fees paid for the Software are non-refundable, even if this Agreement is terminated before the end of a subscription period.''',
          ),

          _buildSection(
            '10. UPDATES AND MODIFICATIONS',
            '''
10.1 SOFTWARE UPDATES
Qudris may, from time to time, provide updates, upgrades, patches, or new versions of the Software. Such updates may be automatically downloaded and installed on your device. You acknowledge and agree that Qudris may update the Software without your prior consent and that this Agreement will apply to all updated versions of the Software.

10.2 FEATURE CHANGES
Qudris reserves the right to add, modify, suspend, or discontinue any features of the Software at any time without prior notice. Qudris shall not be liable to you or any third party for any such modifications or discontinuations.

10.3 AMENDMENT OF AGREEMENT
Qudris may amend this Agreement from time to time. We will notify you of material changes by:

(a) Posting the updated Agreement within the Software;
(b) Sending an email to the address associated with your account; or
(c) Displaying a notice within the Software.

Your continued use of the Software after such notification constitutes your acceptance of the amended Agreement. If you do not agree to the amended terms, you must cease using the Software and terminate this Agreement.''',
          ),

          _buildSection(
            '11. GENERAL PROVISIONS',
            '''
11.1 GOVERNING LAW
This Agreement shall be governed by and construed in accordance with the laws of the Federal Republic of Nigeria, without regard to its conflict of law principles. The United Nations Convention on Contracts for the International Sale of Goods shall not apply to this Agreement.

11.2 JURISDICTION AND VENUE
Any dispute, controversy, or claim arising out of or relating to this Agreement, or the breach, termination, or invalidity thereof, shall be subject to the exclusive jurisdiction of the courts of Lagos State, Nigeria. You hereby irrevocably consent to the jurisdiction of such courts and waive any objections to venue therein.

11.3 DISPUTE RESOLUTION
Before initiating any legal proceedings, the parties agree to attempt to resolve any dispute through good-faith negotiations. If the dispute cannot be resolved within thirty (30) days, either party may pursue legal remedies.

11.4 ENTIRE AGREEMENT
This Agreement, together with any additional terms, policies, or guidelines referenced herein or made available through the Software, constitutes the entire agreement between you and Qudris regarding the Software and supersedes all prior or contemporaneous agreements, communications, and understandings, whether written or oral.

11.5 SEVERABILITY
If any provision of this Agreement is held to be invalid, illegal, or unenforceable by a court of competent jurisdiction, the remaining provisions shall continue in full force and effect. The invalid provision shall be replaced with a valid provision that most closely approximates the intent and economic effect of the invalid provision.

11.6 WAIVER
No waiver of any term or condition of this Agreement shall be deemed a further or continuing waiver of such term or any other term. Qudris's failure to assert any right or provision under this Agreement shall not constitute a waiver of such right or provision.

11.7 ASSIGNMENT
You may not assign or transfer this Agreement or any rights hereunder, whether by operation of law or otherwise, without Qudris's prior written consent. Qudris may assign this Agreement, in whole or in part, without your consent. Any attempted assignment in violation of this provision shall be null and void.

11.8 FORCE MAJEURE
Qudris shall not be liable for any failure or delay in performance under this Agreement due to causes beyond its reasonable control, including but not limited to acts of God, war, terrorism, riots, embargoes, acts of civil or military authorities, fire, floods, accidents, pandemics, strikes, or shortages of transportation, facilities, fuel, energy, labor, or materials.

11.9 EXPORT CONTROL
You agree to comply with all applicable export and import laws and regulations. You represent that you are not located in, under the control of, or a national or resident of any country to which the United States or other relevant jurisdiction has embargoed goods or services.

11.10 U.S. GOVERNMENT RIGHTS
If you are a U.S. government entity or if this Agreement otherwise becomes subject to the Federal Acquisition Regulations (FAR), you acknowledge that the Software qualifies as "commercial computer software" and that any use, duplication, or disclosure by the government is subject to the restrictions set forth in this Agreement.

11.11 INTERPRETATION
The headings in this Agreement are for convenience only and shall not affect the interpretation of this Agreement. The terms "including," "include," and "includes" shall be deemed to be followed by the phrase "without limitation."

11.12 LANGUAGE
This Agreement is drafted in the English language. If this Agreement is translated into any other language, the English version shall prevail in the event of any conflict or ambiguity.''',
          ),

          _buildSection('12. CONTACT INFORMATION', '''
If you have any questions, concerns, or requests regarding this Agreement or the Software, please contact us at:

Qudris Integral CNC
Email: support@qudris.com
Website: www.qudris.com

For legal inquiries:
Email: legal@qudris.com

For data protection inquiries:
Email: privacy@qudris.com'''),

          const SizedBox(height: 32),

          _buildAcknowledgment(),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubtitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildLastUpdated(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontStyle: FontStyle.italic,
        color: Colors.grey[600],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildImportantNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        border: Border.all(color: Colors.orange.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Text(
                'IMPORTANT NOTICE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'PLEASE READ THIS END USER LICENSE AGREEMENT CAREFULLY BEFORE USING THE SOFTWARE. BY DOWNLOADING, INSTALLING, OR USING QUDRIS SHOPKEEPER, YOU AGREE TO BE BOUND BY THE TERMS OF THIS AGREEMENT. IF YOU DO NOT AGREE TO THESE TERMS, DO NOT USE THE SOFTWARE.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(fontSize: 14, height: 1.6),
          textAlign: TextAlign.justify,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAcknowledgment() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        border: Border.all(color: Colors.blue.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ACKNOWLEDGMENT',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'BY USING QUDRIS SHOPKEEPER, YOU ACKNOWLEDGE THAT YOU HAVE READ THIS AGREEMENT, UNDERSTAND IT, AND AGREE TO BE BOUND BY ITS TERMS AND CONDITIONS. YOU FURTHER ACKNOWLEDGE THAT THIS AGREEMENT REPRESENTS THE COMPLETE AND EXCLUSIVE STATEMENT OF THE AGREEMENT BETWEEN YOU AND QUDRIS INTEGRAL CNC CONCERNING THE SOFTWARE.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '© 2025 Qudris Integral CNC. All rights reserved.',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

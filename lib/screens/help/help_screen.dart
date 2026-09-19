import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_strings.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kistify_app_bar.dart';

/// Where the full standard operating procedure lives. Kept next to the
/// screen that links to it so the two can't drift apart.
const sopUrl = 'https://kistify.web.app/sop';

/// Opens the SOP in the device browser, and says so plainly if it can't
/// rather than doing nothing when a tap looked like it should work.
Future<void> openSop(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(Uri.parse(sopUrl), mode: LaunchMode.externalApplication);
  if (!ok) {
    messenger.showSnackBar(const SnackBar(content: Text(sopUrl)));
  }
}

/// The short version of the SOP, inside the app.
///
/// The content lives here rather than in app_strings.dart on purpose: that
/// file is a dictionary of interface labels, and burying paragraphs of
/// prose in it makes both harder to read. This is a document, so it is
/// written as one — a list of sections, each with both languages side by
/// side, which also makes it obvious when a translation is missing.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bn = context.watch<LocaleProvider>().isBangla;
    return Scaffold(
      appBar: KistifyAppBar(title: S.t(context, 'how_it_works')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final s in _sections)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0x1A0F6E5C),
                          foregroundColor: AppColors.primary,
                          child: Icon(s.icon, size: 17),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            bn ? s.titleBn : s.titleEn,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.heading),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bn ? s.bodyBn : s.bodyEn,
                      style: const TextStyle(fontSize: 13.5, height: 1.65),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          // This used to be a line of plain text naming the URL, which left
          // the full SOP with no way to reach it from inside the app at all.
          OutlinedButton.icon(
            onPressed: () => openSop(context),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
            label: Text(bn ? 'বিস্তারিত নিয়মকানুন (SOP)' : 'Full standard operating procedure'),
          ),
          const SizedBox(height: 8),
          Text(
            sopUrl,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: AppColors.mutedText),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section {
  final IconData icon;
  final String titleBn;
  final String titleEn;
  final String bodyBn;
  final String bodyEn;
  const _Section(this.icon, this.titleBn, this.titleEn, this.bodyBn, this.bodyEn);
}

const _sections = <_Section>[
  _Section(
    Icons.flag_outlined,
    'শুরু করবেন যেভাবে',
    'Getting started',
    '১. একটি গ্রুপ তৈরি করুন — ধরন বেছে নিন (কিস্তি কালেকশন, সঞ্চয়, বা লটারি/সমিতি)।\n'
        '২. সদস্য ট্যাব থেকে বন্ধুদের যোগ করুন — তাদের ইমেইল দিয়ে খুঁজে নিতে পারবেন।\n'
        '৩. অন্তত একজনকে Admin বা Collector বানান।\n'
        '৪. এরপর প্রতি মাসে যে যার কিস্তির এন্ট্রি দেবেন।',
    '1. Create a group and pick its type (instalment collection, savings, or lottery/ROSCA).\n'
        '2. Add your friends from the Members tab — you can find them by email.\n'
        '3. Make at least one of them an Admin or Collector.\n'
        '4. From then on, everyone records their own monthly instalment.',
  ),
  _Section(
    Icons.badge_outlined,
    'কে কী করতে পারে',
    'Who can do what',
    'Creator — সব কিছু: পরিকল্পনা বদলানো, সদস্য যোগ/বাদ, ভূমিকা বদলানো, গ্রুপ মুছে ফেলা।\n'
        'Admin — এন্ট্রি অনুমোদন/প্রত্যাখ্যান, রিপোর্ট ও লগ দেখা।\n'
        'Collector — এন্ট্রি অনুমোদন/প্রত্যাখ্যান, বিল্ডার/ব্যাংকে জমার এন্ট্রি।\n'
        'Member — নিজের কিস্তির এন্ট্রি দেওয়া, সবার হিসাব দেখা।\n\n'
        'একজন Creator-ই থাকেন, এবং কেউ নিজের ভূমিকা নিজে বদলাতে পারেন না।\n\n'
        'অনুমোদিত এন্ট্রি বাতিল করতে পারেন শুধু Creator — এবং বিল্ডারে টাকা পাঠানোর পর তিনিও পারেন না।',
    'Creator — everything: edit the plan, add or remove members, change roles, delete the group.\n'
        'Admin — approve or reject entries, see reports and the log.\n'
        'Collector — approve or reject entries, record payments out to the builder or bank.\n'
        'Member — record their own instalments and see the shared accounts.\n\n'
        'There is exactly one Creator, and nobody can change their own role.\n\n'
        'Only the Creator can void an approved entry — and once the money has gone to the '
        'builder, not even they can.',
  ),
  _Section(
    Icons.verified_outlined,
    'অনুমোদন কীভাবে কাজ করে',
    'How approval works',
    'কেউ এন্ট্রি দিলে সেটি প্রথমে "অনুমোদনের অপেক্ষায়" থাকে। অন্য একজন Admin বা Collector '
        'সেটি অনুমোদন করলে তবেই হিসাবে যোগ হয়।\n\n'
        'নিজের এন্ট্রি নিজে অনুমোদন করা যায় না — এটাই মূল সুরক্ষা। তাই গ্রুপে অন্তত দুজন '
        'অনুমোদনকারী থাকা দরকার।\n\n'
        'আপনি একাই সব সামলাতে চাইলে Group Management থেকে "আমি একাই ম্যানেজ করব" চালু করুন — '
        'তখন অনুমোদনের ধাপ থাকবে না, আপনি সবার হয়ে এন্ট্রি দিতে পারবেন।',
    'A new entry starts as "pending". It only counts once a different Admin or Collector '
        'approves it.\n\n'
        'Nobody can approve their own entry — that is the whole safeguard, and it is why a '
        'group needs at least two approvers.\n\n'
        'If you would rather run it single-handed, switch on "I will manage this alone" in '
        'Group Management: the approval step disappears and you record entries for everyone.',
  ),
  _Section(
    Icons.casino_outlined,
    'লটারি / সমিতি',
    'Lottery / ROSCA',
    'প্রতি মাসে সবাই নিজের অংশ জমা দেন, আর লটারিতে একজন পুরো পট পান — এটি সুদমুক্ত ঋণ, '
        'যা তিনি বাকি মাসগুলোতে নিজের অংশ দিয়ে শোধ করেন।\n\n'
        'যিনি একবার জিতেছেন তিনি পরের ড্রগুলো থেকে বাদ পড়েন, তাই সবাই একবার করে পান। '
        'ড্র অ্যাপ নিজে করতে পারে, অথবা সামনাসামনি ড্র হলে Admin বিজয়ীর নাম লিখে দিতে পারেন — '
        'দুটোই আলাদা করে রেকর্ড থাকে, আর ফলাফল পরে বদলানো যায় না।',
    'Everyone pays their share each month and one member takes the whole pot — an '
        'interest-free loan they repay by continuing to pay their share.\n\n'
        'A past winner drops out of later draws, so everyone gets exactly one turn. The app '
        'can draw at random, or an Admin can record the winner of a draw held in person; both '
        'are recorded as such, and a result can never be edited afterwards.',
  ),
  _Section(
    Icons.upload_file_outlined,
    'পুরোনো হিসাব আনা',
    'Bringing old records in',
    'আগে Excel-এ হিসাব রাখতেন? Group Management → "পুরোনো হিসাব আমদানি" থেকে নমুনা ফাইল '
        'নামিয়ে পূরণ করে আপলোড করুন।\n\n'
        'একই ফাইলেই দুই ধরনের সারি দিতে পারবেন — সদস্যদের কিস্তি, আর বিল্ডার বা ব্যাংকে '
        'পাঠানো টাকা। প্রথম ঘরে "কিস্তি" না "জমা" লিখে দিলেই হলো।\n\n'
        'আপলোডের পরই কিছু লেখা হয় না — আগে দেখাবে কতগুলো যোগ হবে, কতগুলো আগে থেকেই আছে, '
        'আর কোন সারিতে সমস্যা। আপনি নিশ্চিত করলে তবেই যোগ হয়।',
    'Kept your accounts in Excel before? Group Management → "Import past records" gives you a '
        'sample file to fill in and upload.\n\n'
        'One file carries both sides of the ledger — members\' instalments and the money sent '
        'out to the builder or bank. The first column says which a row is.\n\n'
        'Nothing is written on upload: you first see how many rows will be added, how many are '
        'already there, and which rows have problems. It only saves once you confirm.',
  ),
  _Section(
    Icons.shield_outlined,
    'নিরাপত্তা ও স্বচ্ছতা',
    'Safety and transparency',
    'আপনার গ্রুপের হিসাব শুধু আপনার গ্রুপের সদস্যরাই দেখতে পান।\n\n'
        'প্রতিটি কাজ — কে এন্ট্রি দিল, কে অনুমোদন করল, কে বাতিল করল — অ্যাক্টিভিটি লগে '
        'লেখা থাকে এবং মোছা যায় না।\n\n'
        'অনুমোদিত এন্ট্রি ভুল হলে Creator সেটি কারণসহ বাতিল করতে পারেন; এন্ট্রি মুছে যায় না, '
        'বাতিল হিসেবে থেকে যায়।\n\n'
        'তবে ওই মাসের টাকা বিল্ডারে পাঠানো হয়ে গেলে আর বাতিল করা যায় না — Creator-ও পারেন না। '
        'টাকা চলে গেছে, তাই হিসাবও আর পেছনে ফেরে না; ভুল হলে পরের মাসে সমন্বয় করতে হয়।',
    "Your group's records are visible to your group's members and nobody else.\n\n"
        'Every action — who filed an entry, who approved it, who cancelled it — is written to '
        'the activity log and cannot be erased.\n\n'
        'If an approved entry turns out to be wrong, the Creator cancels it with a reason. It '
        'is never deleted; it stays on the record as cancelled.\n\n'
        'Once that month\'s money has gone to the builder, not even the Creator can void it. '
        'The money has left; the record follows it. A mistake found afterwards is settled in '
        'the following month.',
  ),
];

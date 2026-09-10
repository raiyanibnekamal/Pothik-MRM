import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(const Locale('bn'));

  void setCode(String code) => emit(Locale(code));

  void toggle() =>
      emit(state.languageCode == 'bn' ? const Locale('en') : const Locale('bn'));
}

class S {
  S(this.locale);
  final Locale locale;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S) ?? S(const Locale('bn'));
  }

  bool get isBn => locale.languageCode == 'bn';

  String get brand => isBn ? 'বিডি রাইড শেয়ার' : 'BD Ride Share';
  String get getOtp => isBn ? 'OTP পান' : 'Get OTP';
  String get phoneLabel => isBn ? 'মোবাইল নম্বর' : 'Mobile number';
  String get phoneHint => '0152170004';
  String get phoneHelper => isBn
      ? '০১ দিয়ে নম্বর লিখুন। টেস্ট ইউজার: 0152170004 · OTP 123456'
      : 'Type 01… Test user: 0152170004 · OTP 123456';
  String get badPhone =>
      isBn ? 'সঠিক বাংলাদেশি মোবাইল নম্বর দিন' : 'Enter a valid Bangladeshi mobile number';
  String get otpTitle => isBn ? 'OTP দিন' : 'Enter OTP';
  String otpSentTo(String phone) =>
      isBn ? '$phone-এ পাঠানো হয়েছে' : 'Sent to $phone';
  String get otpHelper =>
      isBn ? 'টেস্ট OTP: 123456' : 'Test OTP: 123456';
  String get otpExpired =>
      isBn ? 'OTP মেয়াদ শেষ হয়েছে। আবার পাঠান।' : 'OTP expired. Send again.';
  String wrongOtp(int n) =>
      isBn ? 'ভুল OTP। আর $n বার সুযোগ আছে।' : 'Wrong OTP. $n attempts left.';
  String get rateLimit =>
      isBn ? 'কিছুক্ষণ পর আবার চেষ্টা করুন।' : 'Please try again in a moment.';
  String get smsDown => isBn ? 'SMS পাঠানো যাচ্ছে না।' : 'SMS cannot be sent.';
  String get resendOtp => isBn ? 'OTP আবার পাঠান' : 'Resend OTP';
  String resendIn(int s) =>
      isBn ? '$s সেকেন্ডে আবার পাঠান' : 'Resend in ${s}s';
  String get verifyOtp => isBn ? 'OTP যাচাই' : 'Verify OTP';
  String get profileSetupTitle => isBn ? 'আপনার নাম' : 'Your name';
  String get nameLabel => isBn ? 'পুরো নাম' : 'Full name';
  String get nameHelper => isBn
      ? '২–১০০ অক্ষর। ড্রাইভার এটি দেখবেন।'
      : '2–100 characters. Shown to drivers.';
  String get continueCta => isBn ? 'এগিয়ে যান' : 'Continue';
  String get logout => isBn ? 'লগ আউট' : 'Log out';
  String get guardianTitle => isBn ? 'ইমার্জেন্সি কন্টাক্ট' : 'Emergency contacts';
  String get guardianBody => isBn
      ? 'SOS চালু হলে এঁরা এসএমএস পাবেন। এখন বাদও দিতে পারেন।'
      : 'Add people who get an SMS if you trigger SOS. You can skip for now.';
  String get addGuardian => isBn ? 'কন্টাক্ট যোগ করুন' : 'Add contact';
  String get skip => isBn ? 'পরে করব' : 'Skip for now';
  String get guardianCap =>
      isBn ? 'সর্বোচ্চ ৩ জন ইমার্জেন্সি কন্টাক্ট।' : 'Maximum 3 emergency contacts.';
  String get permissionTitle => isBn
      ? 'লোকেশন রাইড খুঁজে দিতে সাহায্য করে'
      : 'Location helps us find a ride';
  String get permissionBody => isBn
      ? 'পিকআপ সেট করতে, কাছের ড্রাইভার দেখাতে এবং আপনার ট্রিপ ট্র্যাক করতে লোকেশন লাগে। বিজ্ঞাপনের জন্য শেয়ার করি না।'
      : 'We use your location to set pickup, show nearby drivers, and keep your trip visible to you. We never share it for ads.';
  String get allowLocation => isBn ? 'এগিয়ে যান' : 'Continue';
  String get locationNeeded => isBn
      ? 'লোকেশন চালু করুন, তা ছাড়া চলবে না'
      : 'Turn on location to continue';
  String get locationServiceOff =>
      isBn ? 'ফোনের লোকেশন বন্ধ আছে' : 'Phone location is off';
  String get locationDenied =>
      isBn ? 'লোকেশন অনুমতি দেওয়া হয়নি' : 'Location permission not granted';
  String get locationBlockedBody => isBn
      ? 'সেটিংস থেকে লোকেশন অনুমতি দিন, তাহলে ম্যাপে আপনার আসল জায়গা দেখাবে।'
      : 'Allow location in settings so the map can show where you really are.';
  String get locationTurnOn => isBn ? 'চালু করুন' : 'Turn on';
  String get locationOpenSettings => isBn ? 'সেটিংস খুলুন' : 'Open settings';
  String get locationSearching =>
      isBn ? 'আপনার জায়গা খোঁজা হচ্ছে…' : 'Finding your location…';
  String get locationWeak => isBn
      ? 'GPS সিগন্যাল দুর্বল — খোলা জায়গায় যান'
      : 'Weak GPS signal — move to open sky';
  String locationAccuracy(int metres) =>
      isBn ? 'নির্ভুলতা ±$metres মিটার' : 'Accurate to ±$metres m';
  String get currentLocation => isBn ? 'বর্তমান লোকেশন' : 'Current location';
  String get useCurrentLocation =>
      isBn ? 'আমার বর্তমান লোকেশন' : 'Use my current location';
  String get pickOnMap => isBn ? 'ম্যাপে জায়গা বাছুন' : 'Set location on map';
  String get pickupPointTitle => isBn ? 'পিকআপ পয়েন্ট' : 'Pickup point';
  String get dropPointTitle => isBn ? 'গন্তব্য' : 'Destination';
  String get dragMapHint => isBn
      ? 'ম্যাপ সরিয়ে পিনটি সঠিক জায়গায় আনুন'
      : 'Drag the map to place the pin';
  String get confirmLocation => isBn ? 'এই জায়গা নিশ্চিত' : 'Confirm location';
  String get searchNoResults =>
      isBn ? 'কিছু পাওয়া যায়নি' : 'Nothing found';
  String get searchOffline => isBn
      ? 'ঠিকানা খোঁজা যাচ্ছে না — ম্যাপে বাছুন'
      : 'Address search unavailable — pick on map';
  String routeSummary(String km, int min) =>
      isBn ? '$km কিমি · $min মিনিট' : '$km km · $min min';
  String get routeApprox => isBn
      ? 'রাস্তা আনা যায়নি, সরলরেখায় হিসাব'
      : 'Road data unavailable, showing direct line';
  String get whereTo => isBn ? 'কোথায় যাবেন?' : 'Where to?';
  String get recents => isBn ? 'সাম্প্রতিক' : 'Recent';
  String get compareTitle => isBn ? 'রাইড বেছে নিন' : 'Choose a ride';
  String get bookRide => isBn ? 'রাইড বুক করুন' : 'Book ride';
  String get bike => isBn ? 'বাইক' : 'Bike';
  String get car => isBn ? 'কার' : 'Car';
  String get cash => isBn ? 'ক্যাশ' : 'Cash';
  String etaMin(int n) => isBn ? '$n মিনিট' : '$n min';
  String get fareBreakdown => isBn ? 'ভাড়ার হিসাব' : 'Fare breakdown';
  String get base => isBn ? 'বেস' : 'Base';
  String get distance => isBn ? 'দূরত্ব' : 'Distance';
  String get time => isBn ? 'সময়' : 'Time';
  String get minFare => isBn ? 'সর্বনিম্ন ভাড়া' : 'Minimum fare';
  String exactCashNudge(String amount) => isBn
      ? 'যদি পারেন $amount রেডি রাখুন'
      : 'Try to keep $amount ready';
  String get findingDriver => isBn ? 'ড্রাইভার খোঁজা হচ্ছে' : 'Finding a driver';
  String get findingHint => isBn
      ? 'কাছের ড্রাইভারদের এই ট্রিপ পাঠানো হচ্ছে।'
      : 'Nearby drivers are being offered this trip.';
  String get cancelRide => isBn ? 'রাইড বাতিল' : 'Cancel ride';
  String get noDrivers =>
      isBn ? 'কাছাকাছি কোনো ড্রাইভার নেই। আবার চেষ্টা করুন।' : 'No drivers nearby. Please try again.';
  String get tryAgain => isBn ? 'আবার চেষ্টা' : 'Try again';
  String get driverFound => isBn ? 'ড্রাইভার পাওয়া গেছে' : 'Driver found';
  String get verified => isBn ? 'ভেরিফাইড' : 'Verified';
  String get matchPlate => isBn ? 'এই নম্বর প্লেট মিলিয়ে নিন' : 'Match this plate';
  String get call => isBn ? 'কল' : 'Call';
  String get shareTrip => isBn ? 'ট্রিপ শেয়ার' : 'Share trip';
  String get pinTellDriver => isBn ? 'ড্রাইভারকে বলুন' : 'Tell the driver this PIN';
  String payDriver(String amount) =>
      isBn ? 'ড্রাইভারকে $amount দিন' : 'Pay the driver $amount';
  String get rateTitle => isBn ? 'ট্রিপ কেমন ছিল?' : 'How was the trip?';
  String get submit => isBn ? 'জমা দিন' : 'Submit';
  String get history => isBn ? 'ট্রিপ হিস্টরি' : 'Trip history';
  String get settings => isBn ? 'সেটিংস' : 'Settings';
  String get language => isBn ? 'ভাষা' : 'Language';
  String get bangla => 'বাংলা';
  String get english => 'English';
  String get legal => isBn ? 'লিগ্যাল' : 'Legal';
  String get terms => isBn ? 'শর্তাবলী' : 'Terms of service';
  String get privacy => isBn ? 'গোপনীয়তা নীতি' : 'Privacy policy';
  String get community => isBn ? 'কমিউনিটি গাইডলাইন' : 'Community guidelines';
  String get offline => isBn ? 'আপনি অফলাইন' : 'You are offline';
  String get otpOffline =>
      isBn ? 'অফলাইনে OTP পাঠানো যাবে না।' : 'OTP cannot be sent offline.';
  String get forceUpdateTitle => isBn ? 'আপডেট প্রয়োজন' : 'Update required';
  String get forceUpdateBody => isBn
      ? 'এই ভার্সনে আর রাইড বুক করা যাবে না। স্টোর থেকে আপডেট করুন।'
      : 'This version can no longer book rides. Please update from the store.';
  String get sos => isBn ? 'জরুরি SOS' : 'Emergency SOS';
  String get sosCancel => isBn ? 'SOS বাতিল' : 'Cancel SOS';
  String get sosHoldHint =>
      isBn ? 'SOS পাঠাতে ৩ সেকেন্ড চেপে ধরুন' : 'Hold 3 seconds to send SOS';
  String sosCountdownHint(int s) => isBn
      ? '$s সেকেন্ডে SOS যাবে। ভুল হলে বাতিল করুন।'
      : 'SOS will send in ${s}s. Cancel if this was a mistake.';
  String get sosActive => isBn
      ? 'SOS চালু। সাহায্যের জন্য জানানো হচ্ছে।'
      : 'SOS is active. Help is being notified.';
  String get sosNotAllowed => isBn
      ? 'রাইড চলাকালীনই SOS ব্যবহার করা যাবে।'
      : 'SOS can only be used during an ongoing ride.';
  String get safetyToolkit => isBn ? 'সেফটি টুলকিট' : 'Safety toolkit';
  String get call999 => isBn ? '৯৯৯ কল করুন' : 'Call 999';
  String get policePacket => isBn
      ? 'বিপদে থাকলে ৯৯৯ কল করুন। রাইড আইডি, প্লেট ও লাইভ লিংক পুলিশকে দিন।'
      : 'If you are in danger, call 999. Share ride ID, plate, and live link with police.';
  String get goOnline => isBn ? 'অনলাইন যান' : 'Go online';
  String get goOffline => isBn ? 'অফলাইন যান' : 'Go offline';
  String get onBreak => isBn ? 'বিরতিতে' : 'On break';
  String get online => isBn ? 'অনলাইন' : 'ONLINE';
  String get offlineStatus => isBn ? 'অফলাইন' : 'OFFLINE';
  String get accept => isBn ? 'গ্রহণ করুন' : 'Accept';
  String get decline => isBn ? 'প্রত্যাখ্যান' : 'Decline';
  String get arrived => isBn ? 'পৌঁছেছি' : "I've arrived";
  String get enterPin => isBn ? 'রাইডার PIN দিন' : 'Enter rider PIN';
  String get startTrip => isBn ? 'ট্রিপ শুরু' : 'Start trip';
  String get completeTrip => isBn ? 'ট্রিপ শেষ' : 'Complete trip';
  String get cashReceived => isBn ? 'ক্যাশ পেয়েছি' : 'Cash received';
  String get earnings => isBn ? 'আয়' : 'Earnings';
  String get today => isBn ? 'আজ' : 'Today';
  String get gross => isBn ? 'গ্রস' : 'Gross';
  String get commission => isBn ? 'কমিশন' : 'Commission';
  String get net => isBn ? 'নেট' : 'Net';
  String get trips => isBn ? 'ট্রিপ' : 'Trips';
  String get debtWarning => isBn ? 'কমিশন বকেয়া' : 'Commission owed';
  String get debtCap => isBn
      ? 'কমিশন বকেয়া সীমা ছাড়িয়েছে। অনলাইন যাওয়া যাবে না।'
      : 'Commission debt is over the limit. You cannot go online.';
  String get graceOver => isBn
      ? 'কাগজপত্র জমা দিয়ে অনুমোদনের পর অনলাইন যাবেন।'
      : 'Submit documents and wait for approval before going online.';
  String get duplicateNidPlate => isBn
      ? 'এই NID / নম্বর প্লেট আগে থেকেই নিবন্ধিত।'
      : 'This NID / number plate is already registered.';
  String get personalTitle => isBn ? 'আপনার তথ্য' : 'About you';
  String get nidLabel => isBn ? 'NID নম্বর' : 'NID number';
  String get dobLabel => isBn ? 'জন্ম তারিখ' : 'Date of birth';
  String get addressLabel => isBn ? 'ঠিকানা' : 'Address';
  String get vehicleTitle => isBn ? 'আপনার গাড়ি' : 'Your vehicle';
  String get vehicleType => isBn ? 'ধরন' : 'Type';
  String get make => isBn ? 'ব্র্যান্ড' : 'Make';
  String get model => isBn ? 'মডেল' : 'Model';
  String get year => isBn ? 'সাল' : 'Year';
  String get color => isBn ? 'রঙ' : 'Color';
  String get plate => isBn ? 'নম্বর প্লেট' : 'Number plate';
  String get documentsTitle => isBn ? 'কাগজপত্র' : 'Documents';
  String get submitDocs => isBn ? 'রিভিউয়ের জন্য জমা' : 'Submit for review';
  String get pendingTitle => isBn ? 'রিভিউ চলছে' : 'Under review';
  String get pendingBody => isBn
      ? 'আপনার কাগজপত্র চেক করা হচ্ছে। সিদ্ধান্ত হলে নোটিফিকেশন যাবে।'
      : 'We are checking your documents. You will get a notification when we decide.';
  String get rejectedTitle => isBn ? 'কাগজপত্র ঠিক করুন' : 'Please fix your documents';
  String get reupload => isBn ? 'আবার আপলোড' : 'Upload again';
  String get batterySaver => isBn ? 'ব্যাটারি সেভার' : 'Battery saver';
  String get outOfZone =>
      isBn ? 'এই এলাকায় এখন সার্ভিস নেই।' : 'Service is not available in this area right now.';
  String get alreadyPaid =>
      isBn ? 'পেমেন্ট ইতিমধ্যে নিশ্চিত।' : 'Payment is already confirmed.';
  String freeCancel(int s) =>
      isBn ? 'ফ্রি বাতিল $sসে' : 'Free cancellation ${s}s';
  String get connecting => isBn ? 'সংযোগ হচ্ছে…' : 'Reconnecting…';
  String get emptyHistory => isBn ? 'এখনো কোনো ট্রিপ নেই' : 'No trips yet';
  String get emptyHistoryCta =>
      isBn ? 'প্রথম রাইড বুক করুন' : 'Book your first ride';
  String get profile => isBn ? 'প্রোফাইল' : 'Profile';
  String get guardians => isBn ? 'গার্ডিয়ান' : 'Guardians';
  String get cancelReasonTitle =>
      isBn ? 'কেন বাতিল করছেন?' : 'Why are you cancelling?';
  String get reasonWait => isBn ? 'ড্রাইভার দেরি করছেন' : 'Driver taking too long';
  String get reasonWrong =>
      isBn ? 'পিকআপ বা গন্তব্য ভুল' : 'Wrong pickup or destination';
  String get reasonPlan => isBn ? 'প্ল্যান বদলেছে' : 'Plans changed';
  String get reasonOther => isBn ? 'অন্য' : 'Other';
  String get confirmCancel => isBn ? 'বাতিল নিশ্চিত' : 'Confirm cancel';
  String get searchHint => isBn ? 'ঢাকার ঠিকানা খুঁজুন' : 'Search Dhaka address';
  String get manualAddress => isBn ? 'নিজে ঠিকানা লিখুন' : 'Enter address manually';
  String get useThisPlace => isBn ? 'এই জায়গা ব্যবহার করুন' : 'Use this place';
  String get waitNoShow => isBn ? 'রাইডারের অপেক্ষা' : 'Waiting for rider';
  String get noShow => isBn ? 'নো-শো দিন' : 'Mark no-show';
  String get navPickup => isBn ? 'পিকআপে ন্যাভ' : 'Navigate to pickup';
  String get navDrop => isBn ? 'ড্রপে ন্যাভ' : 'Navigate to drop';
  String get requestNew => isBn ? 'নতুন রাইড রিকোয়েস্ট' : 'New ride request';
  String get dropArea => isBn ? 'ড্রপ এলাকা' : 'Drop area';
  String get done => isBn ? 'ঠিক আছে' : 'Done';
  String get photoOptional => isBn ? 'ছবি (ঐচ্ছিক)' : 'Photo (optional)';
  String get emailOptional => isBn ? 'ইমেইল (ঐচ্ছিক)' : 'Email (optional)';
  String get editProfile => isBn ? 'প্রোফাইল এডিট' : 'Edit profile';
  String get save => isBn ? 'সেভ' : 'Save';
  String get tripComplete => isBn ? 'ট্রিপ সম্পন্ন' : 'Trip complete';
  String get homePlace => isBn ? 'বাসা' : 'Home';
  String get workPlace => isBn ? 'অফিস' : 'Work';
  String get policeCopy => isBn
      ? '৯৯৯ · রাইড আইডি, ড্রাইভার নাম, প্লেট, লাইভ লিংক দিন।'
      : '999 · Give ride ID, driver name, plate, live link.';
  String get shareWhatsApp => isBn ? 'WhatsApp-এ শেয়ার' : 'Share on WhatsApp';
  String get firstTripPin => isBn
      ? 'গাড়িতে উঠার আগে PIN বলুন। প্লেট মিলিয়ে নিন।'
      : 'Say the PIN before you get in. Match the plate.';
  String get navHome => isBn ? 'হোম' : 'Home';
  String get navServices => isBn ? 'সার্ভিস' : 'Services';
  String get navActivity => isBn ? 'অ্যাক্টিভিটি' : 'Activity';
  String get navAccount => isBn ? 'অ্যাকাউন্ট' : 'Account';
  String get navEarnings => isBn ? 'আয়' : 'Earnings';
  String get driverWelcomeTitle =>
      isBn ? 'ড্রাইভার হিসেবে স্বাগতম' : 'Welcome, driver partner';
  String get driverWelcomeBody => isBn
      ? 'অনলাইন যান, রাইড গ্রহণ করুন, নিরাপদে ট্রিপ শেষ করুন।'
      : 'Go online, accept rides, and complete trips safely.';
  String get driverWelcomeGo => isBn ? 'শুরু করি' : "Let's go";
  String driverTodayChip(String amount) =>
      isBn ? 'আজ $amount' : 'Today $amount';
  String get driverEarningsSubtitle => isBn
      ? 'আজকের আয় ও কমিশন এক নজরে'
      : "Today's earnings and commission at a glance";
  String get driverTipsTitle => isBn ? 'টিপস' : 'Tips';
  String get driverTip1 => isBn
      ? 'অনলাইন থাকলে কাছাকাছি রিকোয়েস্ট দ্রুত আসে।'
      : 'Stay online to receive nearby requests faster.';
  String get driverTip2 => isBn
      ? 'PIN যাচাই ছাড়া ট্রিপ শুরু করবেন না।'
      : 'Never start a trip without verifying the rider PIN.';
  String get driverTip3 => isBn
      ? 'ক্যাশ পেয়েছি নিশ্চিত করার পরই পরবর্তী রাইড নিন।'
      : 'Confirm cash before taking the next ride.';
  String get driverActivitySubtitle => isBn
      ? 'সম্পন্ন ট্রিপের হিস্টরি'
      : 'Your completed trip history';
  String get driverEmptyActivity => isBn
      ? 'অনলাইন গিয়ে প্রথম ট্রিপ সম্পন্ন করুন।'
      : 'Go online and complete your first trip.';
  String get driverVehicleSection => isBn ? 'আপনার গাড়ি' : 'Your vehicle';
  String get driverKycApproved => isBn ? 'KYC অনুমোদিত' : 'KYC approved';
  String get driverKycPending => isBn ? 'KYC রিভিউ চলছে' : 'KYC under review';
  String get driverKycGrace => isBn ? '২৪ ঘণ্টা গ্রেস পিরিয়ড' : '24h grace period';
  String get driverSupport => isBn
      ? 'সাপোর্ট: support@bdride.share · ০১৫২১৭০০০৪'
      : 'Support: support@bdride.share · 0152170004';
  String get driverBatteryHint => isBn
      ? 'ব্যাকগ্রাউন্ড GPS কম ব্যবহার করে'
      : 'Uses less background GPS';
  String get driverEndBreak => isBn ? 'বিরতি শেষ' : 'End break';
  String get driverHeadingPickup =>
      isBn ? 'পিকআপের দিকে যান' : 'Head to pickup';
  String get driverHeadingDrop =>
      isBn ? 'ড্রপ-অফের দিকে যান' : 'Head to drop-off';
  String get pickupShort => isBn ? 'পিকআপ' : 'Pickup';
  String get forYou => isBn ? 'আপনার জন্য' : 'For you';
  String get later => isBn ? 'পরে' : 'Later';
  String get trip => isBn ? 'ট্রিপ' : 'Trip';
  String get reserve => isBn ? 'রিজার্ভ' : 'Reserve';
  String get servicesTitle => isBn ? 'সার্ভিস' : 'Services';
  String get servicesSubtitle =>
      isBn ? 'যেখানে খুশি যান' : 'Go anywhere';
  String get locationBanner => isBn
      ? 'লোকেশন শেয়ার বন্ধ। চালু করতে ট্যাপ করুন'
      : 'Location sharing disabled. Tap here to enable';
  String get whenTrip => isBn ? 'কখন রাইড লাগবে?' : 'When do you need a trip?';
  String get tripNow => isBn ? 'এখনই' : 'Now';
  String get tripNowBody =>
      isBn ? 'এখনই রিকোয়েস্ট করুন, উঠে যান।' : 'Request a trip, hop in and go.';
  String get tripLater => isBn ? 'পরে' : 'Later';
  String get tripLaterBody => isBn
      ? 'আগে থেকে রিজার্ভ করুন, নিশ্চিন্তে থাকুন।'
      : 'Reserve for extra peace of mind.';
  String get upcoming => isBn ? 'আসন্ন' : 'Upcoming';
  String get past => isBn ? 'আগের' : 'Past';
  String get noUpcoming =>
      isBn ? 'আসন্ন কোনো ট্রিপ নেই' : 'You have no upcoming trips';
  String get reserveCta => isBn ? 'ট্রিপ রিজার্ভ করুন →' : 'Reserve your trip →';
  String get noPast =>
      isBn ? 'সাম্প্রতিক কোনো অ্যাক্টিভিটি নেই' : "You don't have any recent activity";
  String get help => isBn ? 'হেল্প' : 'Help';
  String get wallet => isBn ? 'ওয়ালেট' : 'Wallet';
  String get safety => isBn ? 'সেফটি' : 'Safety';
  String get inbox => isBn ? 'ইনবক্স' : 'Inbox';
  String get safetyHub => isBn ? 'সেফটি হাব' : 'Safety hub';
  String get safetyPrefs => isBn ? 'সেফটি পছন্দ' : 'Safety preferences';
  String get safetyPrefsBody => isBn
      ? 'PIN, গার্ডিয়ান ও ট্রিপ শেয়ার ম্যানেজ করুন।'
      : 'Manage PIN, guardians and trip share.';
  String get pinVerification => isBn ? 'PIN যাচাই' : 'PIN verification';
  String get pinVerificationBody =>
      isBn ? 'সঠিক গাড়িতে উঠতে PIN ব্যবহার করুন।' : 'Use PIN to get in the right car.';
  String get emergencyContacts =>
      isBn ? 'ইমার্জেন্সি কন্টাক্ট' : 'Emergency contacts';
  String get emergencyContactsBody =>
      isBn ? 'জরুরি হলে এঁদের জানানো হবে।' : "We'll call them in case of emergency.";
  String get shareTripLoc =>
      isBn ? 'ট্রিপ লোকেশন শেয়ার' : 'Share trip location';
  String get shareTripLocBody =>
      isBn ? 'কন্টাক্টরা ট্রিপ ফলো করতে পারবে।' : 'Let contacts follow your trips.';
  String get cashOnlyNote => isBn
      ? 'P0-তে শুধু ক্যাশ। ওয়ালেট পরে আসবে।'
      : 'Cash only in P0. Wallet comes later.';
  String get manageAccount =>
      isBn ? 'অ্যাকাউন্ট ম্যানেজ' : 'Manage account';
  String get contacts => isBn ? 'কন্টাক্ট' : 'Contacts';
  String get welcomeTitle =>
      isBn ? 'বিডি রাইড শেয়ারে স্বাগতম' : 'Welcome to BD Ride Share';
  String get welcomeBody =>
      isBn ? 'প্রথম ট্রিপ বুক করতে সাহায্য লাগবে?' : 'Need help booking your first trip?';
  String get welcomeYes => isBn ? 'হ্যাঁ, সাহায্য লাগবে' : 'Yes, I need help';
  String get welcomeNo => isBn ? 'না ধন্যবাদ' : 'No thanks';
  String get ratingLabel => isBn ? 'রেটিং' : 'Rating';
}

class SDelegate extends LocalizationsDelegate<S> {
  const SDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'bn' || locale.languageCode == 'en';

  @override
  Future<S> load(Locale locale) async => S(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<S> old) => false;
}

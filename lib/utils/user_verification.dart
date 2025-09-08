import 'package:campus_crush/models/user_model.dart';

class UserVerification {
  // Founder's email - Krishna
  static const String _founderEmail = 'krishna.12408588@lpu.in';

  // Check if user is the founder
  static bool isFounder(User user) {
    return user.email.toLowerCase() == _founderEmail.toLowerCase();
  }

  // Check if user should be verified (founder or other verified users)
  static bool shouldBeVerified(User user) {
    return isFounder(user) || user.isVerified;
  }

  // Get verification status for display - only show for founder
  static bool getDisplayVerificationStatus(User user) {
    return isFounder(user);
  }
}

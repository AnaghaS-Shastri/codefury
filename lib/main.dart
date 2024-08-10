import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OTP Login Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(),
      routes: {
        '/phoneAuth': (context) => const PhoneAuthScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate splash delay
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/phoneAuth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({Key? key}) : super(key: key);

  @override
  _PhoneAuthScreenState createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String _verificationId = '';
  bool _codeSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneNumberController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyPhoneNumber() async {
    setState(() {
      _isLoading = true;
    });

    await _auth.verifyPhoneNumber(
      phoneNumber: '+91${_phoneNumberController.text}',
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        setState(() {
          _isLoading = false;
        });
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: ${e.message}')),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _isLoading = false;
          _codeSent = true;
          _verificationId = verificationId;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> _signInWithOTP() async {
    setState(() {
      _isLoading = true;
    });

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text,
      );
      await _auth.signInWithCredential(credential);

      // After successful login, save user data:
      await _saveUserData();

      setState(() {
        _isLoading = false;
      });
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: ${e.message}')),
      );
    }
  }

  Future<void> _saveUserData() async {
    // Get user's current location
    Position position = await _determinePosition();

    // Save phone number and location to Firebase Realtime Database
    DatabaseReference ref = FirebaseDatabase.instance.ref('users');
    String? userId = _auth.currentUser?.uid;
    await ref.child(userId!).set({
      'phoneNumber': _phoneNumberController.text,
      'latitude': position.latitude,
      'longitude': position.longitude,
    });
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await  await Geolocator.checkPermission();;
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return Future.error(
            'Location permissions are denied (whileInUse or always).');
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Authentication'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _isLoading
              ? const CircularProgressIndicator()
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (!_codeSent)
                TextField(
                  controller: _phoneNumberController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'Enter phone number',
                  ),
                ),
              const SizedBox(height: 20),
              if (!_codeSent)
                ElevatedButton(
                  onPressed: _verifyPhoneNumber,
                  child: const Text('Send OTP'),
                ),
              if (_codeSent)
                Pinput(
                  controller: _otpController,
                  length: 6,
                  onCompleted: (pin) => _signInWithOTP(),
                ),
              const SizedBox(height: 20),
              if (_codeSent)
                ElevatedButton(
                  onPressed: _signInWithOTP,
                  child: const Text('Verify OTP'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _signOut,
          child: const Text('Logout'),
        ),
      ),
    );
  }
}
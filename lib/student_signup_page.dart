import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

class StudentSignupPage extends StatefulWidget {
  const StudentSignupPage({super.key});

  @override
  State<StudentSignupPage> createState() => _StudentSignupPageState();
}

class _StudentSignupPageState extends State<StudentSignupPage> {

  final TextEditingController nameController = TextEditingController();
  final TextEditingController regController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref("students");

  bool otpSent = false;
  bool isLoading = false;
  String verificationId = "";
  bool isPreRegistered = false;
  bool isValidRegisterNumber = false;

  String selectedRoute = "Select Route";
  String selectedStop = "Select Stop";

  // ✅ REAL ROUTES & STOPS (from your images)
  final Map<String, List<String>> routeStops = {

    "Ashok Pillar ": [
      "Ashok Pillar",
      "Postal Colony BS",
      "Thambiah Redddy Road",
      "Panagal Park",
      "V N Road",
      "Toddhunter Nagar",
      "Saidapet",
      "Panagal Maaligai",
      "Chinnamalai",
      "Guindy Subway",
      "Meenambakkam Cement Road",
      "Meenambakkam Jain College",
      "Pallavaram",
      "Nagalkeni Petrol Bunk",
      "Nagalkeni MGR Silai",
      "Thiruneermalai"
    ],

    "Koyambedu ": [
      "Vijayakanth Mandapam",
      "C.M.B.T",
      "M.M.D.A",
      "Thiru Nagar",
      "Opp.to SRM(Vadapalani)",
      "Vadapalani B.S",
      "Aavichi School",
      "Virugambakkam Church",
      "Alwar Thirunagar",
      "Valasaravakkam MKT",
      "Kesavarthini(Valasaravakkam)",
      "Metro Nagar (Valasaravakkam)",
      "Ganesh Nagar Valasaravakkam"
      "Porur Rountana",
      "Madananthapuram",
      "Moulivakam(Kundrathur)",
      "GerugamBakam Litt.Flow",
      "Kovur",
      "Kundrathur"
    ],

    "Nesapakkam ": [
      "Nesapakkam",
      "MGR Nagar BS ",
      "Kasi Theatre",
      "Ekkatuthangal",
      "Ambal Nagar",
      "Olympia",
      "Guindy",
      "Airport",
      "Chromepet",
      "MIET Gate",
      "TB Hospital Santorium",
      "Ramar Kovil Santorium",
      "Siddha Hospital MEPZ"
      "MEPZ"
    ],

    "Madipakkam ": [
      "Madipakkam BS",
      "Madipakkam Axis Bank",
      "Ganesh Nagar(Keelkattalai)"
      "Ponniamman Koil MPK",
      "Iyappan Kovil MPk",
      "Keelkattalai",
      "Eachangadu(Keelkattalai)",
      "Kovilambakkam",
      "Vellakallu"
      "Santhoshpuram",
      "Gowrivakkam",
      "Sembakkam",
      "kamarajapuram",
      "Rajakilpakkam",
      "Adhi Nagar",
      "Convent School",
      "Poondy Bazzar",
      "Christian College"
    ],

    "Velachery ": [
      "Vijaya Nagar (Velachery)",
      "Railway Station (Velachery)",
      "Jerusalem College",
      "Narayanapuram",
      "Pallikaranai(Ganesh Nagar)",
      "Pallikaranai (BS)",
      "Oil Company Pallikaranai",
      "Medavakkam",
      "Vijay Nagaram - Medavakkam ",
      "Koot Road Medavakkam",
      "Mahalakshmi Nagar",
      "Camp Road",
      "Selaiyur"

    ],

    "Chengalpet ": [
      "ITI (Chengalpet)",
      "Chengalpattu GH",
      "Rattinakinaru",
      "Ganesh Bhavan (Chengalpet)",
      "Thirumalai Theater(chengalpet)",
      "New Bus Stand(Chengalpet)",
      "Chengalpattu Old Bus Stand",
      "JSP Hospital",
      "Mahindra City",
      "SP Koil",
      "SP Koil (Ford)",
      "Maraimalai Nagar BS",
      "Kattangulathur",
      "SRM College",
      "Srinivasapuram"
      "Guduvanchery BS",
      "Guduvanchery EB",
      "Urapakkam BS",
      "Urapakkam School Stop",
      "Vandalur Zoo",
      "Vandalur Gate",
      "Eraniamman Koil (Vandalur)",
      "Perungalathur BS (GST Road)",
      "Erikara (Perungalathur)",
      "Irumbuliyur BS",
      "Kone Krishna",
      "Kulam(Mudichur RD)",
      "Lakshmipuram Serviec Road"

    ],

    "Anakaputhur ": [
      "Kumarananchavadi",
      "Maangadu",
      "Anakaputhur Bus Stand",
      "Ammam Kovil Anakaputhur ",
      "Anakaputhur School Stop",
      "Arunmathi Theater",
      "Pammal",
      "Pozhichalur Koot Road",
      "Krishna Nagar Pillaiyar Kovil",
      "Muthamil Nagar",
      "Hotel Mars Pallavaram ",
      "Attuthotty (Pallavaram)",
      "Pallavaram Signal",
      "Tambaram",
      "Royal Club Kishkintha",
      "Dharkast"
    ],

    "Sithalapakkam ": [
      "Sankarapuram",
      "Indira Nagar Sithalapakkam",
      "Sithalapakkam Bus Stop",
      "Jaya Nagar (Sithalapakkam)",
      "Sithalapakkam Koot Road",
      "Kanni Kovil",
      "Housing Board Sithalapakkam",
      "Noothancherry",
      "Madambakkam Sivan Kovil",
      "Kozhipannai (Madambakkam)",
      "A.L.S Nagar",
      "Yashwanth Nagar",
      "Padmavathi Nagar",
      "Bharath Engg.College",
      "Indra Nagar(Camp Road)",
      "EX.Serviceman Enclave",
      "Ambedkar Nagar (Camp Road)"
    ],

    "Padappai ": [
      "Padappai",
      "Mannivakkam Koot Road",
      "Natesan School Mannivakkam",
      "lakshmi Nagar (Mudichur RD)",
      "Mudichur",
      "Madhanapuram (Mudichur RD)",
      "Parvathi Nagar (Mudichur)",
      "Perungalathur Old",
      "Padmavathy Kalyana Mandabam",
      "Bharathi Nagar(Mudichur RD)"
      "Krishna Nagar(Mudichur RD)",
      "Vetri Nagar (Mudichur RD)"
    ],
  };

  List<String> get routes => routeStops.keys.toList();
  List<String> get stops =>
      selectedRoute != "Select Route" ? routeStops[selectedRoute]! : [];

  //================= CHECK REGISTER NUMBER =================
  Future<void> checkRegisterNumber() async {

    if (regController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter Register Number")),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("http://10.17.162.165:3000/check-student"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "registerNumber": regController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (data["status"] == "ALREADY_REGISTERED") {
        setState(() {
          isValidRegisterNumber = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("This register number is already registered"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (data["status"] == "NOT_FOUND") {
        setState(() {
          isValidRegisterNumber = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid Register Number"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (data["status"] == "PRE_REGISTERED") {
        setState(() {
          selectedRoute = data["route"];
          selectedStop = data["stop"];
          isValidRegisterNumber = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Register number verified"),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Server error"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------------- SEND OTP ----------------
  Future<void> sendOtp() async {
    setState(() => isLoading = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: "+91${phoneController.text.trim()}",
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (e) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message ?? "OTP failed")));
      },
      codeSent: (vid, token) {
        setState(() {
          verificationId = vid;
          otpSent = true;
          isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (vid) {
        verificationId = vid;
      },
    );
  }
//to pre-fill the route and stop dropdowns
  Future<void> fetchStudentDetails(String registerNumber) async {
    try {
      final response = await http.post(
        Uri.parse("http://YOUR_IP:3000/get-student-by-reg"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "registerNumber": registerNumber,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          selectedRoute = data["route"];
          selectedStop = data["stop"];
          isPreRegistered = true; // 🔥 LOCK DROPDOWNS
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pre-registered student found")),
        );
      } else {
        setState(() {
          isPreRegistered = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Student not pre-registered")),
        );
      }
    } catch (e) {
      print("Error fetching student: $e");
    }
  }

  // ---------------- VERIFY OTP & SAVE ----------------
  Future<void> verifyOtpAndRegister() async {
    try {
      setState(() => isLoading = true);

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otpController.text.trim(),
      );

      UserCredential userCred =
      await _auth.signInWithCredential(credential);

      String uid = userCred.user!.uid;

      await _db.child(uid).set({
        "name": nameController.text.trim(),
        "registerNumber": regController.text.trim(),
        "phone": phoneController.text.trim(),
        "route": selectedRoute,
        "stop": selectedStop,
        "uid": uid,
      });

      setState(() => isLoading = false);
      Navigator.pop(context);

    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Invalid OTP")));
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/student2.jpg',
              height: 240,
              fit: BoxFit.cover,
              color: Colors.white.withOpacity(0.1),
              colorBlendMode: BlendMode.lighten,
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [

                  const SizedBox(height: 180),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 25,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar( radius: 40,
                          backgroundColor: Colors.teal.withOpacity(0.15),
                          child: const Icon(Icons.person_add,
                              size: 40, color: Colors.teal),
                        ),

                        const SizedBox(height: 20),

                        const Text("STUDENT SIGN UP",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal)),

                        const SizedBox(height: 16),

                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.badge, color: Colors.teal),
                            hintText: "Register Number",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onEditingComplete: () {
                            fetchStudentDetails(nameController.text.trim());
                          },
                        ),
                        inputBox(regController, "Student Name", Icons.person),
                        inputBox(phoneController, "Phone Number", Icons.phone,
                            type: TextInputType.phone),

                        DropdownButtonFormField<String>(
                          value: selectedRoute,
                          items: ["Select Route", ...routes]
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: isPreRegistered
                              ? null   // 🔒 disabled
                              : (val) {
                            setState(() {
                              selectedRoute = val!;
                              selectedStop = "Select Stop";
                            });
                          },
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.route, color: Colors.teal),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        DropdownButtonFormField<String>(
                          value: selectedStop,
                          items: ["Select Stop", ...stops]
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: isPreRegistered
                              ? null   // 🔒 disabled
                              : (val) {
                            setState(() => selectedStop = val!);
                          },
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.location_on, color: Colors.teal),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),

                        if (otpSent)
                          inputBox(otpController, "Enter OTP", Icons.lock,
                              type: TextInputType.number),

                        const SizedBox(height: 16),

                        isLoading
                            ? const CircularProgressIndicator()
                            :ElevatedButton(
                          onPressed: otpSent
                              ? verifyOtpAndRegister
                              : () async {
                            await checkRegisterNumber();
                            if (isValidRegisterNumber) {
                              sendOtp();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                          ),
                          child: Text(
                            otpSent ? "VERIFY & CREATE" : "SEND OTP",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget inputBox(TextEditingController controller, String hint, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.teal),
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget dropDownBox(
      String hint,
      List<String> items,
      String value,
      Function(String?) onChanged,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),

        // 🔒 Disable if register number is verified
        onChanged: isValidRegisterNumber ? null : onChanged,

        decoration: InputDecoration(
          prefixIcon: Icon(
            hint == "Route Name" ? Icons.route : Icons.location_on,
            color: Colors.teal,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(ParkingApp());
}

class ParkingApp extends StatelessWidget {
  const ParkingApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ParkingHomePage(),
    );
  }
}

class ParkingHomePage extends StatelessWidget {
  const ParkingHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double scaffoldHeight = MediaQuery.of(context).size.height;
    double scaffoldWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned(
              top: (scaffoldHeight / 4), // Adjust the top position
              width: scaffoldWidth,
              child: Center(
                child: Text(
                  'Find parking meters in Vancouver',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Center(
              child: Container(
                height: scaffoldHeight / 2,
                width: scaffoldWidth / 2,
                child: Image.asset('assets/images/mater.png'),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.large(
          onPressed: () {
            Future.delayed(Duration(milliseconds: 300), () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ParkingMapPage(),
                ),
              );
            });
          },
          backgroundColor: Colors.green,
          elevation: 10,
          child: Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: Text(
              'Park now',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

class ParkingMapPage extends StatefulWidget {
  @override
  _ParkingMapPageState createState() => _ParkingMapPageState();
}

class _ParkingMapPageState extends State<ParkingMapPage> {
  GoogleMapController? _mapController;
  Location _location = Location();
  LatLng _initialCameraPosition =
      LatLng(49.2827, -123.1207); // Default initial position

  List<Map<String, dynamic>> parkingData = [];
  BitmapDescriptor markerIcon = BitmapDescriptor.defaultMarker;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadParkingData(); // Call this to get current location
    addCustomIcon();
  }

  void _loadParkingData() async {
    String data = await rootBundle.loadString('assets/parking-meters.json');
    setState(() {
      parkingData = List<Map<String, dynamic>>.from(json.decode(data));
    });
  }

  void _getCurrentLocation() async {
    LocationData? locationData = await _location.getLocation();
    if (locationData != null) {
      setState(() {
        _initialCameraPosition =
            LatLng(locationData.latitude!, locationData.longitude!);
      });
    }
  }

  void addCustomIcon() {
    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(), "assets/images/meter2.png")
        .then((icon) {
      setState(() {
        markerIcon = icon;
      });
    });
    ;
  }

  Marker? _selectedMarker;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Parking Map'),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              setState(() {
                _mapController = controller;
              });
            },
            initialCameraPosition: CameraPosition(
              target: _initialCameraPosition,
              zoom: 16.0,
            ),
            myLocationEnabled: true,
            mapToolbarEnabled: false,
            markers: _createMarkers(),
            onTap: (_) {
              setState(() {
                _selectedMarker = null; // Deselect marker if map is tapped
              });
            },
          ),
          if (_selectedMarker != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width /
                      1.5, // Reduce width by half
                  child: ElevatedButton(
                    onPressed: () {
                      _navigateToLocation(_selectedMarker!.position);
                    },
                    style: ElevatedButton.styleFrom(
                      primary: Colors.green, // Green background color
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16.0), // Rounded edges
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Navigate to Parking',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Set<Marker> _createMarkers() {
    return parkingData.map((parking) {
      Map<String, dynamic> geometry = parking['geom']['geometry'];
      List<double> coordinates = List<double>.from(geometry['coordinates']);
      LatLng position = LatLng(coordinates[1], coordinates[0]);
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          _initialCameraPosition,
          16.0,
        ),
      );

      return Marker(
        markerId: MarkerId(position.toString()),
        position: position,
        icon: markerIcon,
        infoWindow: InfoWindow(
          title: "PaybyPhone: " + parking['pay_phone'],
          snippet: parking['timeineffe'],
        ),
        onTap: () {
          setState(() {
            _selectedMarker = Marker(
              markerId: MarkerId(position.toString()),
              position: position,
              icon: markerIcon,
              infoWindow: InfoWindow(
                title: "PaybyPhone: " + parking['pay_phone'],
                snippet: parking['timeineffe'],
              ),
            );
          });
        },
      );
    }).toSet();
  }

  void _navigateToLocation(LatLng destination) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}

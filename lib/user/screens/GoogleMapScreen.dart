import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/system_utils.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../../main/components/CommonScaffoldComponent.dart';
import '../../main/models/CityListModel.dart';
import '../../main/models/PlaceAddressModel.dart';
import '../../main/utils/Constants.dart';

class GoogleMapScreen extends StatefulWidget {
  static final kInitialPosition = LatLng(-33.8567844, 151.213108);
  final bool isPick;
  final bool isSaveAddress;
  final bool isAddAddress;

  GoogleMapScreen(
      {this.isPick = true,
      this.isSaveAddress = false,
      this.isAddAddress = false});

  @override
  _GoogleMapScreenState createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen>
    with WidgetsBindingObserver {
  GoogleMapController? _googleMapController;
  LatLng? _selectedPosition;
  String _selectedAddress = '';
  bool _isLoadingMap = true;
  bool _isResolvingAddress = false;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initializeMap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _googleMapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      initializeMap();
    }
  }

  Future<LatLng?> _getSelectedCityCenter() async {
    try {
      final cityJson = getJSONAsync(CITY_DATA);
      if (cityJson.isEmpty) return null;

      final city = CityModel.fromJson(cityJson);
      final List<String> searchQueries = [];

      if ((city.address ?? '').trim().isNotEmpty) {
        searchQueries.add(city.address!.trim());
      }

      final String cityWithCountry = [
        city.name ?? '',
        city.countryName ?? '',
      ].where((e) => e.trim().isNotEmpty).join(', ');
      if (cityWithCountry.trim().isNotEmpty) {
        searchQueries.add(cityWithCountry.trim());
      }

      if ((city.name ?? '').trim().isNotEmpty) {
        searchQueries.add(city.name!.trim());
      }

      for (final query in searchQueries.toSet()) {
        try {
          final locations = await locationFromAddress(query);
          if (locations.isNotEmpty) {
            return LatLng(locations.first.latitude, locations.first.longitude);
          }
        } catch (_) {}
      }
    } catch (_) {}

    return null;
  }

  Future<void> initializeMap() async {
    try {
      LatLng currentPosition = GoogleMapScreen.kInitialPosition;
      final LatLng? selectedCityCenter = await _getSelectedCityCenter();
      if (selectedCityCenter != null) {
        currentPosition = selectedCityCenter;
      }

      bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      bool hasPermission = false;

      if (isLocationEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied &&
            selectedCityCenter == null) {
          permission = await Geolocator.requestPermission();
        }

        hasPermission = permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse;

        if (hasPermission && selectedCityCenter == null) {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          currentPosition = LatLng(position.latitude, position.longitude);
        }
      }

      _hasLocationPermission = hasPermission;
      _selectedPosition = _selectedPosition ?? currentPosition;
      await _resolveAddress(_selectedPosition!);
    } catch (e) {
      _selectedPosition = _selectedPosition ?? GoogleMapScreen.kInitialPosition;
      _selectedAddress =
          '${_selectedPosition!.latitude.toStringAsFixed(6)}, ${_selectedPosition!.longitude.toStringAsFixed(6)}';
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMap = false;
        });
      }
    }
  }

  Future<void> _resolveAddress(LatLng position) async {
    if (mounted) {
      setState(() {
        _isResolvingAddress = true;
      });
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark p = placemarks.first;
        List<String> parts = [
          p.name ?? '',
          p.street ?? '',
          p.subLocality ?? '',
          p.locality ?? '',
          p.administrativeArea ?? '',
          p.country ?? '',
        ].where((e) => e.trim().isNotEmpty).toList();

        _selectedAddress = parts.isNotEmpty ? parts.join(', ') : '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      } else {
        _selectedAddress = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      }
    } catch (e) {
      _selectedAddress = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingAddress = false;
        });
      }
    }
  }

  Future<void> _updateSelectedPosition(LatLng position) async {
    _selectedPosition = position;
    setState(() {});
    await _resolveAddress(position);
  }

  void _confirmSelection() {
    if (_selectedPosition == null) return;

    PlaceAddressModel selectedModel = PlaceAddressModel(
      latitude: _selectedPosition!.latitude,
      longitude: _selectedPosition!.longitude,
      placeId: '',
      placeAddress: _selectedAddress,
    );

    finish(context, selectedModel);
  }

  String buildTitle() {
    if (widget.isSaveAddress || widget.isAddAddress) {
      return language.selectLocation;
    } else if (widget.isPick) {
      return language.selectPickupLocation;
    } else {
      return language.selectDeliveryLocation;
    }
  }

  String buildButtonText() {
    if (widget.isPick) {
      return language.confirmPickupLocation;
    } else if (widget.isAddAddress) {
      return language.addNewAddress;
    } else {
      return language.confirmDeliveryLocation;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffoldComponent(
      appBarTitle: buildTitle(),
      body: _isLoadingMap
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(target: _selectedPosition!, zoom: 16),
                    mapType: MapType.normal,
                    myLocationEnabled: _hasLocationPermission,
                    myLocationButtonEnabled: _hasLocationPermission,
                    onMapCreated: (GoogleMapController controller) {
                      _googleMapController = controller;
                    },
                    markers: _selectedPosition == null
                        ? {}
                        : {
                            Marker(
                              markerId: MarkerId('selected_location'),
                              position: _selectedPosition!,
                              draggable: true,
                              onDragEnd: _updateSelectedPosition,
                            ),
                          },
                    onTap: _updateSelectedPosition,
                    zoomGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                  ),
                ),
                Container(
                  width: context.width(),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(language.selectLocation, style: boldTextStyle()),
                      SizedBox(height: 8),
                      _isResolvingAddress
                          ? Row(
                              children: [
                                SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text(language.pleaseWait),
                              ],
                            )
                          : Text(_selectedAddress, style: primaryTextStyle(), maxLines: 3, overflow: TextOverflow.ellipsis),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _confirmSelection,
                          child: Text(buildButtonText()),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

library google_places_flutter;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_places_flutter/model/place_details.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart';

class GooglePlaceAutoCompleteTextField extends StatefulWidget {
  final InputDecoration inputDecoration;
  final ItemClick itemClick;
  final GestureTapCallback onTap;
  final GetPlaceDetailswWithLatLng getPlaceDetailWithLatLng;
  final bool isLatLngRequired;

  final TextStyle textStyle;
  final String googleAPIKey;
  final int debounceTime;
  final List<String> countries;
  final TextEditingController textEditingController;

  GooglePlaceAutoCompleteTextField({
    @required this.textEditingController,
    @required this.googleAPIKey,
    this.debounceTime: 600,
    this.inputDecoration: const InputDecoration(),
    this.itemClick,
    this.onTap,
    this.isLatLngRequired = true,
    this.textStyle: const TextStyle(),
    this.countries,
    this.getPlaceDetailWithLatLng,
  });

  @override
  _GooglePlaceAutoCompleteTextFieldState createState() =>
      _GooglePlaceAutoCompleteTextFieldState();
}

class _GooglePlaceAutoCompleteTextFieldState
    extends State<GooglePlaceAutoCompleteTextField> {
  final subject = PublishSubject<String>();
  OverlayEntry _overlayEntry;
  final alPredictions = <Prediction>[];

  TextEditingController controller = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  bool isSearched = false;

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        onTap: widget.onTap,
        decoration: widget.inputDecoration,
        style: widget.textStyle,
        controller: widget.textEditingController,
        onChanged: (string) => (subject.add(string)),
      ),
    );
  }

  getLocation(String text) async {
    Dio dio = Dio();
    String url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$text&key=${widget.googleAPIKey}";

    if (widget.countries != null) {
      for (int i = 0; i < widget.countries.length; i++) {
        String country = widget.countries[i];

        if (i == 0) {
          url = url + "&components=country:$country";
        } else {
          url = url + "|" + "country:" + country;
        }
      }
    }

    Response response = await dio.get(url);
    PlacesAutocompleteResponse subscriptionResponse =
        PlacesAutocompleteResponse.fromJson(response.data);

    if (text.length == 0) {
      alPredictions.clear();
      this._overlayEntry.remove();
      return;
    }

    isSearched = false;
    if (subscriptionResponse.predictions.length > 0) {
      alPredictions.clear();
      alPredictions.addAll(subscriptionResponse.predictions);
    }

    //if (this._overlayEntry == null)

    this._overlayEntry = null;
    this._overlayEntry = this._createOverlayEntry();
    Overlay.of(context).insert(this._overlayEntry);
    //   this._overlayEntry.markNeedsBuild();
  }

  @override
  void initState() {
    subject.stream
        .distinct()
        .debounceTime(Duration(milliseconds: widget.debounceTime))
        .listen(textChanged);
  }

  textChanged(String text) async {
    getLocation(text);
  }

  OverlayEntry _createOverlayEntry() {
    if (context?.findRenderObject() != null) {
      RenderBox renderBox = context.findRenderObject();
      var size = renderBox.size;
      var offset = renderBox.localToGlobal(Offset.zero);
      return OverlayEntry(
        builder: (context) => Positioned(
          left: offset.dx,
          top: size.height + offset.dy,
          width: size.width,
          child: CompositedTransformFollower(
            showWhenUnlinked: false,
            link: this._layerLink,
            offset: Offset(0.0, size.height + 5.0),
            child: Material(
              elevation: 1.0,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: alPredictions.length,
                itemBuilder: (BuildContext context, int index) {
                  return InkWell(
                    onTap: () {
                      if (index < alPredictions.length) {
                        widget.itemClick?.call(alPredictions[index]);
                        if (!widget.isLatLngRequired) return;
                        getPlaceDetailsFromPlaceId(alPredictions[index]);
                        removeOverlay();
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(10),
                      child: Text(alPredictions[index].description),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }
  }

  removeOverlay() {
    alPredictions.clear();
    this._overlayEntry = this._createOverlayEntry();
    if (context != null) {
      Overlay.of(context).insert(this._overlayEntry);
      this._overlayEntry.markNeedsBuild();
    }
  }

  Future<Response> getPlaceDetailsFromPlaceId(Prediction prediction) async {
    final url = "https://maps.googleapis.com/maps/api/place/details/json?placeid=${prediction.placeId}&key=${widget.googleAPIKey}";
    Response response = await Dio().get(url);
    PlaceDetails placeDetails = PlaceDetails.fromJson(response.data);
    prediction.lat = placeDetails.result.geometry.location.lat.toString();
    prediction.lng = placeDetails.result.geometry.location.lng.toString();
    widget.getPlaceDetailWithLatLng?.call(prediction);
  }
}

PlacesAutocompleteResponse parseResponse(Map responseBody) {
  return PlacesAutocompleteResponse.fromJson(responseBody);
}

PlaceDetails parsePlaceDetailMap(Map responseBody) {
  return PlaceDetails.fromJson(responseBody);
}

typedef ItemClick = void Function(Prediction postalCodeResponse);
typedef GetPlaceDetailswWithLatLng = void Function(
    Prediction postalCodeResponse);

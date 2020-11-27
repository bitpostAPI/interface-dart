import 'package:http/http.dart' as http;
import 'dart:convert';

class BitpostInterface{
  String baseURL;
  String walletToken;
  String apiKey;

  BitpostInterface({String walletToken, String apiKey, bool testnet = false}):
        walletToken = walletToken, apiKey = apiKey{
    if(testnet){
      baseURL = "https://testnet-api.bitpost.co";
    } else {
      baseURL = "https://api.bitpost.co";
    }
  }

  Future<List<double>> getFeerates(int maxFeerate, {int size = 50, int target, bool canReduceFee = true}) async{
    var url = baseURL + '/feerateset?maxfeerate=${maxFeerate}&size=${size}&canreducefee=${canReduceFee}';
    var response = await http.get(url);
    if(response.statusCode >= 400) throw Exception('Failed to get feerates. status code=' + response.statusCode.toString());

    var rawFeerates = jsonDecode(response.body)['data']['feerates'];
    var feerates = List<double>();
    rawFeerates.forEach((v) => feerates.add(v.toDouble()));
    return feerates;
  }

  BitpostRequest createBitpostRequest(List<String> rawTxs, int targetInSeconds, {int delay = 1, bool broadcastLowestFee = false}){
    return BitpostRequest(rawTxs, targetInSeconds, delay: delay,
        broadcastLowestFeerate: broadcastLowestFee, walletToken: walletToken,
        apiKey: apiKey, baseURL: baseURL);
  }
}

class BitpostRequest{
  String apiKey;
  String walletToken;
  String baseURL;

  List<String> rawTxs;
  int absoluteEpochTarget;
  int delay = 1;
  bool broadcastLowestFeerate = false;

  String id;
  dynamic answer;

  BitpostRequest(this.rawTxs, target, {this.delay, this.broadcastLowestFeerate,
                    this.apiKey, this.walletToken, this.baseURL}):
        absoluteEpochTarget = toEpoch(target){}

   static int toEpoch(int rawTarget){
    if(rawTarget < 100000000){
      return (rawTarget + DateTime.now().millisecondsSinceEpoch/1000).round();
    } else if(rawTarget > 10000000000){
      return (rawTarget/1000).round();
    } else {
      return rawTarget;
    }
   }

   String createQueryString(){
    var queryString = 'target=${absoluteEpochTarget}&delay=${delay}';
    if(broadcastLowestFeerate) queryString += '&broadcast=0';
    if(walletToken != null) queryString += '&wallettoken=${walletToken}';
    if(apiKey != null) queryString += '&key=${apiKey}';
    return queryString;
   }

   dynamic sendRequest({bool printBefore =true, bool printAfter = true}) async{
    var queryString = createQueryString();
    var url = baseURL + '/request?' + queryString;

    if(printBefore){
      print('Sending ${rawTxs.length} signed transactions...');
      print('URL=' + url);
    }

    var response = await http.post(url, body: rawTxs.toString());
    answer = jsonDecode(response.body);

    if(response.statusCode < 400) id = answer['data']['id'];

    if(printAfter){
      print('Satus code=' + response.statusCode.toString());
      print(answer);
    }

    return answer;
   }
}

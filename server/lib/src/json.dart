import 'dart:convert';

import 'package:shelf/shelf.dart';

Response jsonResponse(Object? body, {int status = 200}) => Response(
      status,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

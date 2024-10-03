import 'dart:convert';

import 'package:base/models/User.dart';
import 'package:base/providers/auth_service.dart';
import 'package:base/utilities/requests/graphql.dart';
import 'package:base/views/root_layout.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:rms/router_rms.dart';
import 'package:rms/view/explore/logic/graphql_search.dart';

class RmsHomeScreen extends StatelessWidget {
  const RmsHomeScreen({super.key, required this.scaffoldKey});
  final LocalKey? scaffoldKey;

  @override
  Widget build(BuildContext context) {
    return RootLayout(
      key: scaffoldKey,
      destinations: rmsDestinations,
      currentIndex: 1,
      child: const Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: LoginAs(),
              )
            ],
          ),
          Expanded(child: Center(child: Text('rms home'))),
        ],
      ),
    );
  }
}

class LoginAs extends StatefulWidget {
  const LoginAs({super.key});

  @override
  State<LoginAs> createState() => _LoginAsState();
}

class _LoginAsState extends State<LoginAs> {
  bool loadingUsers = true;
  List<User> users = [];
  List<String> loginUsers = [];
  String? sub;

  @override
  void initState() {
    _getUsers();
    super.initState();
  }

  Future<void> _getUsers() async {
    if (mounted) {
      setState(() {
        loadingUsers = true;
      });
    }
    sub = (await (await AuthService().getUser())?.getUserAttributes())
        ?.firstWhere((a) => a.name == "sub")
        .value;
    SearchResult userResult = await searchGraphql(
      model: User.classType,
      isMounted: () => mounted,
      nextToken: null,
    );
    users.addAll(userResult.items?.map(User.fromJson).toList() ?? []);
    while (userResult.nextToken != null) {
      userResult = await searchGraphql(
        model: User.classType,
        isMounted: () => mounted,
        nextToken: Uri.encodeComponent(userResult.nextToken ?? ""),
      );
      users.addAll(userResult.items?.map(User.fromJson).toList() ?? []);
    }
    if (mounted) {
      setState(() {
        loadingUsers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return loadingUsers
        ? const SizedBox(
            height: 25,
            width: 25,
            child: CircularProgressIndicator(),
          )
        : PopupMenuButton(
            itemBuilder: (context) {
              List<PopupMenuItem> menuItems = [];
              for (User user in users.where((u) => u.id != sub)) {
                menuItems.add(
                  PopupMenuItem(
                    value: user,
                    child: Text(user.email ?? ""),
                  ),
                );
              }
              return menuItems;
            },
            onSelected: (value) async {
              List<Future> futures = [];
              for (String accessId in (value as User).accessIds) {
                String query = '''
                query _ {
                  get${User.schema.name}(${User.ID.fieldName}: "$accessId") {
                    ${generateGraphqlQueryFields(schema: User.schema)}
                  }
                }''';
                futures.add(
                  gqlQuery(query).then((result) {
                    Map? resultMap = jsonDecode(result.body) is Map
                        ? ((jsonDecode(result.body) as Map)['data']?['get${User.schema.name}'])
                        : null;
                    if (resultMap != null) {
                      loginUsers.add(accessId);
                    }
                  }),
                );
              }
              await Future.wait(futures);
              Response updateReponse = await gqlMutation(
                input: {User.ID.fieldName: sub, User.LOGINAS.fieldName: loginUsers},
                model: User.classType,
                mutationType: GraphQLMutationType.update,
              );
              Map? resultMap = jsonDecode(updateReponse.body) is Map
                  ? ((jsonDecode(updateReponse.body) as Map)['data']?['update${User.schema.name}'])
                  : null;
              if (resultMap != null) {
                await AuthService().signOut();
              }
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Login As"),
                SizedBox(
                  width: 8,
                ),
                Icon(Icons.arrow_drop_down_outlined)
              ],
            ),
          );
  }
}

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:base/models/ModelProvider.dart';
import 'package:base/utilities/extensions/string.dart';
import 'package:base/utilities/models/model_services.dart';
import 'package:base/views/root_layout.dart';
import 'package:base/routing/router.dart' as router;
import 'package:base/views/tabbed_model_screen.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rms/rms_home_screen.dart';
import 'package:rms/view/create_edit/view/create_edit_layout.dart';
import 'package:rms/view/explore/explorer_graphql.dart';
import 'package:rms/view/period_close/period_close_stepper.dart';
import 'package:rms/view/report_generation/report_stepper.dart';
import 'package:rms/view/upload/uploader.dart';

List<String> rmsModelNames = [
  "Contact",
  "Account",
  "Address",
  "Advisor",
  "Client",
  "Commission",
  "PendingCommission",
  "PendingAdjustment",
  "Adjustment",
  "Organization",
  "Product",
  "PayoutGrid",
  "AdvisorOverride",
  "AdvisorSplit",
  "ProductCategory",
  "Vendor",
  if (kDebugMode) ...testModelNames,
];

List<String> testModelNames = [
  "Tag",
  "Test",
  "RelatedType",
  "TestTag",
  "Client2",
];

const CustomNavigationDestination rmsHome = CustomNavigationDestination(
  label: 'RMS',
  icon: Icon(Icons.attach_money),
  route: '/rms',
);

List<CustomNavigationDestination> rmsDestinations = [
  home,
  rmsHome,
  ...ModelProvider.instance.modelSchemas
      .where(
        (e) =>
            e.fields != null &&
            rmsModelNames.map((element) => element.toLowerCase()).contains(e.name.toLowerCase()),
      )
      .where(
        (e) => !rootOnlyDestinations.any((el) => e.name.toLowerCase().startsWith(el.toLowerCase())),
      )
      .map(
        (e) => CustomNavigationDestination(
          label: e.pluralName?.split(RegExp('(?=[A-Z])')).join(" ") ??
              e.name.split(RegExp('(?=[A-Z])')).join(" "),
          icon: const Icon(Icons.list),
          route: '/rms/${e.name.toLowerCase()}',
        ),
      ),
  router.blank,
  const CustomNavigationDestination(
    label: 'Reports',
    icon: Icon(Icons.picture_as_pdf),
    route: '/rms/reports',
  ),
  const CustomNavigationDestination(
    label: 'Period Close',
    icon: Icon(Icons.picture_as_pdf),
    route: '/rms/periodClose',
  ),
];

List<GoRoute> rmsRoutes(LocalKey? pageKey, LocalKey? scaffoldKey) {
  List<GoRoute> modelRoutes = modelGoRoutes(
    pageKey: pageKey,
    scaffoldKey: scaffoldKey,
    destinations: rmsDestinations,
    filterList: rmsModelNames,
    startingIndex: 2,
  );
  return [
    GoRoute(
      path: '/rms',
      pageBuilder: (context, state) => MaterialPage<void>(
        key: pageKey,
        child: RmsHomeScreen(scaffoldKey: scaffoldKey),
      ),
      routes: [
        ...modelRoutes,
        GoRoute(
          path: 'reports',
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: RootLayout(
              key: scaffoldKey,
              destinations: rmsDestinations,
              currentIndex: modelRoutes.length + 3,
              child: const Center(child: ReportSteps()),
            ),
          ),
        ),
        GoRoute(
          path: 'periodClose',
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: RootLayout(
              key: scaffoldKey,
              destinations: rmsDestinations,
              currentIndex: modelRoutes.length + 4,
              child: const Center(child: PeriodCloseStepper()),
            ),
          ),
        ),
      ],
    ),
  ];
}

List<Tab> getTabTitles(ModelType<Model> model, String? pluralModelName) {
  String prettyName = pluralModelName != null
      ? pluralModelName.split(RegExp('(?=[A-Z])')).join(" ")
      : model.modelName().split(RegExp('(?=[A-Z])')).join(" ");

  return [
    Tab(text: 'Search $prettyName'),
    Tab(text: 'Add $prettyName'),
    Tab(text: 'Bulk Upload $prettyName'),
  ];
}

List<GoRoute> modelGoRoutes({
  required LocalKey? pageKey,
  required LocalKey? scaffoldKey,
  required List<CustomNavigationDestination> destinations,
  required List<String> filterList,
  required int startingIndex,
}) {
  return [
    ...ModelProvider.instance.modelSchemas
        .where(
          (e) =>
              e.fields != null &&
              getJoinTableData(
                    model: ModelProvider.instance.getModelTypeByModelName(e.name),
                  ) ==
                  null,
        )
        .where(
          (e) =>
              filterList.isEmpty ||
              filterList.map((el) => el.toLowerCase()).contains(e.name.toLowerCase()),
        )
        .mapIndexed(
      (index, e) {
        ModelType<Model> model = ModelProvider.instance.getModelTypeByModelName(e.name);
        Widget tabbed({
          required BuildContext context,
          required GoRouterState state,
          String? itemId,
          int? initialIndex,
        }) =>
            RootLayout(
              key: scaffoldKey,
              destinations: destinations,
              currentIndex: startingIndex + index,
              child: TabbedModelScreen(
                state: state,
                tabs: getTabTitles(
                  model,
                  e.pluralName,
                ),
                initialIndex: initialIndex ?? int.parse(state.uri.queryParameters['tab'] ?? '0'),
                tabViews: [
                  ExplorerGraphQL(
                    key: UniqueKey(),
                    model: model,
                    initialChips: model == Account.classType
                        ? [
                            "${Account.CLIENTSTATUS.fieldName.toFirstUpper().splitCamelCase()}: ${AccountClientStatusEnum.Active.name}",
                          ]
                        : model == Client.classType
                            ? [
                                "${Client.CLIENTSTATUS.fieldName.toFirstUpper().splitCamelCase()}: ${AccountClientStatusEnum.Active.name}",
                              ]
                            : [],
                    initialOrChips: model == Account.classType
                        ? [
                            Account.EXTERNALACCOUNT.fieldName.toFirstUpper().splitCamelCase(),
                            Account.DISPLAYNAME1.fieldName.toFirstUpper().splitCamelCase(),
                          ]
                        : model == Client.classType
                            ? [
                                Client.LASTNAME.fieldName.toFirstUpper().splitCamelCase(),
                                "Referred By",
                              ]
                            : [],
                  ),
                  CreateEditLayout(
                    model: model,
                    itemId: itemId,
                  ),
                  Uploader(
                    model: model,
                    stopModels: router.stopModels,
                  ),
                ],
                onTaps: [
                  () {
                    if (itemId != null) {
                      String? path =
                          state.fullPath?.replaceAll("/$itemId", "").replaceAll("/:iid", "");
                      if (path != null) {
                        GoRouter.of(context).replace("$path?tab=0");
                      }
                    }
                  },
                  () {},
                  () {
                    if (itemId != null) {
                      String? path =
                          state.fullPath?.replaceAll("/$itemId", "").replaceAll("/:iid", "");
                      if (path != null) {
                        GoRouter.of(context).replace("$path?tab=2");
                      }
                    }
                  },
                ],
              ),
            );
        return GoRoute(
          path: e.name.toLowerCase(),
          pageBuilder: (context, state) => MaterialPage<void>(
            key: state.pageKey,
            child: tabbed(context: context, state: state),
          ),
          routes: [
            GoRoute(
              path: ':iid',
              pageBuilder: (context, state) => MaterialPage(
                key: state.pageKey,
                child: tabbed(
                  context: context,
                  state: state,
                  itemId: state.pathParameters['iid'],
                  initialIndex: 1,
                ),
              ),
            ),
          ],
        );
      },
    ),
  ];
}

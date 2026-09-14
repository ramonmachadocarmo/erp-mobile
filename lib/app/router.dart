import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/assets/presentation/pages/assets_pages.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/users_page.dart';
import '../features/auth/presentation/providers/auth_notifier.dart';
import '../features/cashflow/presentation/cashflow_pages.dart';
import '../features/config/presentation/pages/payment_page.dart';
import '../features/config/presentation/pages/rules_page.dart';
import '../features/config/presentation/pages/units_page.dart';
import '../features/invoicing/presentation/invoicing_pages.dart';
import '../features/logistics/presentation/pages/conference_page.dart';
import '../features/logistics/presentation/pages/inbound_page.dart';
import '../features/purchasing/presentation/pages/purchasing_pages.dart';
import '../features/sales/presentation/pages/delivery_page.dart';
import '../features/sales/presentation/pages/picking_page.dart';
import '../features/sales/presentation/pages/routes_page.dart';
import '../features/sales/presentation/pages/sales_pages.dart';
import '../features/stock/presentation/pages/assemblies_page.dart';
import '../features/stock/presentation/pages/balances_prices_page.dart';
import '../features/stock/presentation/pages/categories_page.dart';
import '../features/stock/presentation/pages/products_page.dart';
import '../features/stock/presentation/pages/warehouses_page.dart';
import 'shell.dart';
import 'splash_page.dart';

const _home = '/estoque/produtos';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authNotifierProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: _home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;
      if (!auth.hydrated) return loc == '/splash' ? null : '/splash';
      final loggingIn = loc == '/login';
      if (!auth.isAuthenticated && !loggingIn) return '/login';
      if (auth.isAuthenticated && (loggingIn || loc == '/splash')) return _home;
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/estoque/produtos', builder: (_, _) => const ProductsPage()),
          GoRoute(path: '/estoque/categorias', builder: (_, _) => const CategoriesPage()),
          GoRoute(path: '/estoque/almoxarifados', builder: (_, _) => const WarehousesPage()),
          GoRoute(path: '/estoque/montagem', builder: (_, _) => const AssembliesPage()),
          GoRoute(path: '/estoque/saldos', builder: (_, _) => const BalancesPage()),
          GoRoute(path: '/estoque/precos', redirect: (_, _) => '/vendas/precos'),
          GoRoute(path: '/vendas/pedidos', builder: (_, _) => const SalesOrdersPage()),
          GoRoute(path: '/vendas/precos', builder: (_, _) => const PricesPage()),
          GoRoute(path: '/vendas/separacao', redirect: (_, _) => '/logistica/separacao'),
          GoRoute(path: '/vendas/entrega', redirect: (_, _) => '/logistica/entrega'),
          GoRoute(path: '/vendas/clientes', builder: (_, _) => const CustomersPage()),
          GoRoute(path: '/compras/orcamentos', builder: (_, _) => const QuotesPage()),
          GoRoute(path: '/compras/pedidos', builder: (_, _) => const PurchaseOrdersPage()),
          GoRoute(path: '/compras/fornecedores', builder: (_, _) => const SuppliersPage()),
          GoRoute(path: '/compras/historico', builder: (_, _) => const PurchaseHistoryPage()),
          GoRoute(path: '/logistica/entrada', builder: (_, _) => const InboundPage()),
          GoRoute(
            path: '/logistica/conferencia',
            builder: (_, _) => const ConferenceListPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => ConferencePage(orderId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/logistica/separacao',
            builder: (_, _) => const SalesOrdersPage(forPicking: true),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => PickingPage(orderId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: '/logistica/entrega', builder: (_, _) => const DeliveryPage()),
          GoRoute(
            path: '/logistica/rotas',
            builder: (_, _) => const RoutesPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => RouteStopsPage(planId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: '/ativos/bens', builder: (_, _) => const AssetsPage()),
          GoRoute(path: '/ativos/movimentos', builder: (_, _) => const AssetMovementsPage()),
          GoRoute(path: '/caixa/resumo', builder: (_, _) => const CashSummaryPage()),
          GoRoute(path: '/caixa/lancamentos', builder: (_, _) => const CashEntriesPage()),
          GoRoute(path: '/fiscal/saida', builder: (_, _) => const InvoicesPage(direction: 'OUT')),
          GoRoute(path: '/fiscal/entrada', builder: (_, _) => const InvoicesPage(direction: 'IN')),
          GoRoute(path: '/config/unidades', builder: (_, _) => const UnitsPage()),
          GoRoute(path: '/config/pagamento', builder: (_, _) => const PaymentPage()),
          GoRoute(path: '/config/usuarios', builder: (_, _) => const UsersPage()),
          GoRoute(path: '/config/regras', builder: (_, _) => const RulesPage()),
          GoRoute(path: '/', redirect: (_, _) => _home),
        ],
      ),
    ],
  );
});

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const shopServer = String.fromEnvironment('SHOP_API_BASE', defaultValue: '');
const shopEndpoint = '/api/locintel/shop/v1';
const shopSlug = String.fromEnvironment('SHOP_STORE_SLUG', defaultValue: 'dumiya');

void main() => runApp(const LocintelShop());

class Store {
  final int id;
  final String name, description, logo, banner, icon, color, whatsapp;
  Store.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num).toInt(), name = '${j['name'] ?? ''}',
        description = '${j['description'] ?? ''}', logo = '${j['logo_url'] ?? ''}',
        banner = '${j['banner_url'] ?? ''}', icon = '${j['icon_url'] ?? ''}',
        color = '${j['primary_color'] ?? '#1769AA'}',
        whatsapp = '${j['whatsapp_number'] ?? ''}';
}
class Product {
  final int id;
  final String name, description, image, currency, categoryId, categoryName;
  final bool featured;
  final double price;
  Product.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num).toInt(), name = '${j['name'] ?? ''}',
        description = '${j['description'] ?? ''}', image = '${j['image_url'] ?? ''}',
        currency = '${j['currency'] ?? ''}',
        categoryId = '${j['category_id'] ?? ''}', categoryName = '${j['category_name'] ?? ''}',
        featured = j['featured'] == true,
        price = (j['price'] as num?)?.toDouble() ?? 0;
}
class ShopApi {
  static Future<Map<String, dynamic>> get(String path, [Map<String, String>? query]) async {
    if (shopServer.isEmpty) throw Exception('Configuration absente : SHOP_API_BASE');
    final base = Uri.parse('${shopServer.replaceAll(RegExp(r'/$'), '')}$shopEndpoint/$path');
    final url = base.replace(queryParameters: query);
    final response = await http.get(url).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw Exception('Serveur HTTP ${response.statusCode}');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) throw const FormatException('Réponse serveur incorrecte');
    return decoded;
  }
  static Future<List<ShopCategory>> categories(int storeId) async =>
      ((await get('stores/$storeId/categories'))['categories'] as List<dynamic>? ?? [])
      .map((item) => ShopCategory.fromJson(Map<String, dynamic>.from(item as Map))).toList();
  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data) async {
    if (shopServer.isEmpty) throw Exception('Configuration absente : SHOP_API_BASE');
    final base = shopServer.replaceAll(RegExp(r'/$'), '');
    final uri = Uri.parse('$base$shopEndpoint/$path');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 25));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Réponse serveur incorrecte');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded['error'] ?? 'Erreur HTTP ${response.statusCode}');
    }
    return decoded;
  }
  static Future<Store> storefront() async {
    final data = await get('storefront/${Uri.encodeComponent(shopSlug)}');
    return Store.fromJson(Map<String, dynamic>.from(data['store'] as Map));
  }
  static Future<List<Store>> stores() async =>
      ((await get('stores'))['stores'] as List<dynamic>? ?? [])
          .map((item) => Store.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
  static Future<List<Product>> products(int storeId, {String search = '', String category = ''}) async =>
      ((await get('stores/$storeId/products', {'q': search, 'category': category}))['products'] as List<dynamic>? ?? [])
          .map((item) => Product.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
}
class ShopCategory {
  final String id, name;
  final int count;
  ShopCategory.fromJson(Map<String, dynamic> j)
      : id = '${j['id'] ?? ''}', name = '${j['name'] ?? ''}', count = (j['count'] as num?)?.toInt() ?? 0;
}
class ShopCart {
  static final Map<int, Map<int, CartItem>> byStore = {};
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);
  static void add(Store store, Product product) {
    final items = byStore.putIfAbsent(store.id, () => {});
    final existing = items[product.id];
    items[product.id] = CartItem(product, (existing?.quantity ?? 0) + 1);
    changes.value++;
  }
  static void setQuantity(Store store, Product product, int quantity) {
    final items = byStore.putIfAbsent(store.id, () => {});
    if (quantity <= 0) { items.remove(product.id); }
    else { items[product.id] = CartItem(product, quantity); }
    changes.value++;
  }
}
class CartItem {
  final Product product;
  final int quantity;
  const CartItem(this.product, this.quantity);
}
class LocintelShop extends StatelessWidget {
  const LocintelShop({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'DUMIYA',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFFF26332), scaffoldBackgroundColor: const Color(0xFFFFFAF7)),
    home: const DumiyaHome(),
  );
}
class CatalogImage extends StatelessWidget {
  final String url;
  final double? height;
  const CatalogImage({super.key, required this.url, this.height});
  @override Widget build(BuildContext context) => url.isEmpty ? const Center(child: Icon(Icons.storefront, size: 42))
    : Image.network(url, height: height, width: double.infinity, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported_outlined, size: 42)));
}
class DumiyaHome extends StatefulWidget {
  const DumiyaHome({super.key});
  @override State<DumiyaHome> createState() => _DumiyaHomeState();
}
class _DumiyaHomeState extends State<DumiyaHome> {
  late Future<Store> storeFuture;
  @override void initState() { super.initState(); reload(); }
  void reload() { storeFuture = ShopApi.storefront(); }
  @override Widget build(BuildContext context) => FutureBuilder<Store>(
    future: storeFuture,
    builder: (context, snapshot) {
      if (snapshot.hasError) return Scaffold(appBar: AppBar(title: const Text('DUMIYA')),
        body: ErrorRetry(message: '${snapshot.error}', onRetry: () => setState(reload)));
      if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return ProductsScreen(store: snapshot.data!);
    });
}
class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});
  @override State<StoresScreen> createState() => _StoresScreenState();
}
class _StoresScreenState extends State<StoresScreen> {
  late Future<List<Store>> future;
  String query = '';
  @override void initState() { super.initState(); refresh(); }
  void refresh() { future = ShopApi.stores(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('LOCINTEL Shop'), centerTitle: false),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: TextField(
        onChanged: (v) => setState(() => query = v.toLowerCase()),
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Rechercher une boutique', filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
      Expanded(child: FutureBuilder<List<Store>>(future: future, builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorRetry(message: '${snapshot.error}', onRetry: () => setState(refresh));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final stores = snapshot.data!.where((s) => s.name.toLowerCase().contains(query)).toList();
        if (stores.isEmpty) return const Center(child: Text('Aucune boutique disponible'));
        return RefreshIndicator(onRefresh: () async { setState(refresh); await future; }, child: ListView.builder(
          itemCount: stores.length, padding: const EdgeInsets.symmetric(horizontal: 14),
          itemBuilder: (context, i) { final store = stores[i];
            return Card(margin: const EdgeInsets.only(bottom: 12), clipBehavior: Clip.antiAlias, child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductsScreen(store: store))),
              child: Row(children: [ SizedBox(width: 105, height: 105, child: CatalogImage(url: store.logo.isNotEmpty ? store.logo : store.icon)),
                Expanded(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(store.name, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 5),
                    Text(store.description, maxLines: 2, overflow: TextOverflow.ellipsis)]))),
                const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.chevron_right))] ))); },
        ));
      }))
    ]),
  );
}
class ProductsScreen extends StatefulWidget {
  final Store store;
  const ProductsScreen({super.key, required this.store});
  @override State<ProductsScreen> createState() => _ProductsScreenState();
}
class _ProductsScreenState extends State<ProductsScreen> {
  late Future<List<Product>> future;
  final searchController = TextEditingController();
  late Future<List<ShopCategory>> categoriesFuture;
  String selectedCategory = '';
  @override void initState() { super.initState(); categoriesFuture = ShopApi.categories(widget.store.id); load(); }
  void load() { future = ShopApi.products(widget.store.id, search: searchController.text, category: selectedCategory); }
  Widget categoryChip(String label, String id) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: ChoiceChip(label: Text(label), selected: selectedCategory == id,
      onSelected: (_) => setState(() { selectedCategory = id; load(); })));
  @override void dispose() { searchController.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Row(children: [
      if (widget.store.logo.isNotEmpty || widget.store.icon.isNotEmpty)
        SizedBox(width: 34, height: 34, child: CatalogImage(url: widget.store.icon.isNotEmpty ? widget.store.icon : widget.store.logo)),
      const SizedBox(width: 8), Flexible(child: Text(widget.store.name, style: const TextStyle(fontWeight: FontWeight.bold)))
    ]), actions: [ValueListenableBuilder<int>(valueListenable: ShopCart.changes, builder: (context, _, __) {
      final qty = ShopCart.byStore[widget.store.id]?.values.fold<int>(0, (sum, item) => sum + item.quantity) ?? 0;
      return Badge(isLabelVisible: qty > 0, label: Text('$qty'), child: IconButton(tooltip: 'Panier', icon: const Icon(Icons.shopping_cart_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopCartScreen(store: widget.store))) ); })]),
    body: Column(children: [
      if (widget.store.banner.isNotEmpty) SizedBox(height: 130, width: double.infinity, child: CatalogImage(url: widget.store.banner)),
      Padding(padding: const EdgeInsets.all(12), child: TextField(controller: searchController, onSubmitted: (_) => setState(load),
        decoration: InputDecoration(hintText: 'Rechercher un produit', prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(onPressed: () => setState(load), icon: const Icon(Icons.arrow_forward)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))))),
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Align(alignment: Alignment.centerLeft, child: Text('Catégories', style: Theme.of(context).textTheme.titleLarge))),
      SizedBox(height: 58, child: FutureBuilder<List<ShopCategory>>(future: categoriesFuture, builder: (context, snap) {
        if (snap.hasError) return const Padding(padding: EdgeInsets.all(8), child: Text('Catégories indisponibles'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          categoryChip('Tous', ''),
          ...snap.data!.map((c) => categoryChip(c.name, c.id)),
        ]);
      })),
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: Align(alignment: Alignment.centerLeft, child: Text('Nos produits', style: Theme.of(context).textTheme.titleLarge))),
      Expanded(child: FutureBuilder<List<Product>>(future: future, builder: (context, snapshot) {
        if (snapshot.hasError) return ErrorRetry(message: '${snapshot.error}', onRetry: () => setState(load));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.isEmpty) return const Center(child: Text('Aucun produit publié'));
        return GridView.builder(padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .71, mainAxisSpacing: 10, crossAxisSpacing: 10),
          itemCount: snapshot.data!.length, itemBuilder: (context, i) {
            final product = snapshot.data![i];
            return Card(clipBehavior: Clip.antiAlias, child: InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetails(product: product, store: widget.store))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Stack(fit: StackFit.expand, children: [CatalogImage(url: product.image), if (product.featured) Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF176A67), borderRadius: BorderRadius.circular(9)), child: const Text('Vedette', style: TextStyle(color: Colors.white, fontSize: 11))))])),
                Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (product.categoryName.isNotEmpty) Text(product.categoryName, maxLines: 1, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text('${product.price.toStringAsFixed(2)} ${product.currency}', style: const TextStyle(fontWeight: FontWeight.bold))
                ])) ])));
          });
      }))
    ]),
  );
}
class ProductDetails extends StatelessWidget {
  final Product product;
  final Store store;
  const ProductDetails({super.key, required this.product, required this.store});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Détail produit')),
    body: ListView(children: [SizedBox(height: 280, child: CatalogImage(url: product.image)),
      Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(product.name, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 10),
        Text('${product.price.toStringAsFixed(2)} ${product.currency}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14), Text(product.description), const SizedBox(height: 22),
        FilledButton.icon(onPressed: () { ShopCart.add(store, product); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produit ajouté au panier'))); }, icon: const Icon(Icons.add_shopping_cart), label: const Text('Ajouter au panier')),
        const SizedBox(height: 8), OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopCartScreen(store: store))), icon: const Icon(Icons.shopping_cart_outlined), label: const Text('Voir mon panier')),
        const SizedBox(height: 8), TextButton.icon(onPressed: () { ShopCart.add(store, product); Navigator.push(context, MaterialPageRoute(builder: (_) => ShopCartScreen(store: store))); }, icon: const Icon(Icons.chat_outlined), label: const Text('Commander via WhatsApp'))
      ]))]));
}
class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorRetry({super.key, required this.message, required this.onRetry});
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.wifi_off, size: 40),
      const SizedBox(height: 12), Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 12), FilledButton(onPressed: onRetry, child: const Text('Réessayer'))])));
}

class ShopCartScreen extends StatefulWidget {
  final Store store;
  const ShopCartScreen({super.key, required this.store});
  @override State<ShopCartScreen> createState() => _ShopCartScreenState();
}
class _ShopCartScreenState extends State<ShopCartScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  bool sending = false;
  @override void dispose() { nameController.dispose(); phoneController.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Panier — ${widget.store.name}')),
    body: ValueListenableBuilder<int>(valueListenable: ShopCart.changes, builder: (context, _, __) {
      final items = ShopCart.byStore[widget.store.id]?.values.toList() ?? [];
      final total = items.fold<double>(0, (sum, e) => sum + e.product.price * e.quantity);
      if (items.isEmpty) return const Center(child: Text('Votre panier est vide'));
      return ListView(padding: const EdgeInsets.all(16), children: [
        ...items.map((item) => Card(child: ListTile(
          leading: SizedBox(width: 56, child: CatalogImage(url: item.product.image)),
          title: Text(item.product.name), subtitle: Text('${item.product.price.toStringAsFixed(2)} ${item.product.currency}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(onPressed: () => ShopCart.setQuantity(widget.store, item.product, item.quantity - 1), icon: const Icon(Icons.remove_circle_outline)),
            Text('${item.quantity}'),
            IconButton(onPressed: () => ShopCart.setQuantity(widget.store, item.product, item.quantity + 1), icon: const Icon(Icons.add_circle_outline)),
          ]),
        ))),
        const SizedBox(height: 12),
        Text('Total estimé : ${total.toStringAsFixed(2)} ${items.first.product.currency}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Votre nom', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone (ex: +243...)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: sending ? null : () => checkout(items), icon: const Icon(Icons.chat_outlined), label: Text(sending ? 'Enregistrement...' : 'Commander via WhatsApp')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: sending ? null : () => pay(items), icon: const Icon(Icons.payments_outlined), label: const Text('Payer avec WonyaPay')),
        const Text('Paiement confirmé exclusivement par Odoo après vérification auprès de WonyaPay.'),
      ]);
    }),
  );
  Future<void> pay(List<CartItem> items) async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim().replaceAll(' ', '');
    if (name.isEmpty || !RegExp(r'^\+?[0-9]{8,15}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saisissez votre nom et un numéro valide')));
      return;
    }
    final numberController = TextEditingController();
    final mobile = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Paiement Mobile Money'),
      content: TextField(controller: numberController, keyboardType: TextInputType.phone,
        decoration: const InputDecoration(hintText: '0991234567', labelText: 'Numéro Mobile Money')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, numberController.text.trim()), child: const Text('Continuer'))
      ]));
    numberController.dispose();
    if (mobile == null) return;
    if (!RegExp(r'^0[0-9]{9}$').hasMatch(mobile)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Numéro Mobile Money invalide')));
      return;
    }
    setState(() => sending = true);
    try {
      final order = await ShopApi.post('orders', {
        'store_id': widget.store.id, 'customer_name': name, 'customer_phone': phone,
        'items': items.map((e) => {'product_id': e.product.id, 'quantity': e.quantity}).toList()
      });
      final reference = '${order['reference']}';
      final token = '${order['checkout_token']}';
      final initiation = await ShopApi.post('payments/initiate', {
        'reference': reference, 'checkout_token': token, 'mobilemoney': mobile
      });
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Paiement en attente'),
        content: Text('Commande $reference — transaction ${initiation['reference']}. Confirmez sur votre téléphone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          FilledButton(onPressed: () async {
            try {
              final status = await ShopApi.post('payments/status', {
                'reference': reference, 'checkout_token': token
              });
              if (!ctx.mounted) return;
              final value = '${status['status']}';
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(
                value == 'paid' ? 'Paiement confirmé' : value == 'failed' ? 'Paiement échoué' : 'Paiement en attente')));
              if (value == 'paid') {
                ShopCart.byStore[widget.store.id]?.clear();
                ShopCart.changes.value++;
                Navigator.pop(ctx);
              }
            } catch (e) {
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
            }
          }, child: const Text('Vérifier le paiement'))
        ]));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
  Future<void> checkout(List<CartItem> items) async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim().replaceAll(' ', '');
    if (name.isEmpty || !RegExp(r'^\+?[0-9]{8,15}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saisissez un nom et un téléphone valide')));
      return;
    }
    setState(() => sending = true);
    try {
      final base = shopServer.replaceAll(RegExp(r'/$'), '');
      final uri = Uri.parse('$base$shopEndpoint/orders');
      final response = await http.post(uri, headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'store_id': widget.store.id, 'customer_name': name, 'customer_phone': phone,
          'items': items.map((e) => {'product_id': e.product.id, 'quantity': e.quantity}).toList()}))
        .timeout(const Duration(seconds: 25));
      final payload = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode != 201) throw Exception(payload['error'] ?? 'Erreur HTTP ${response.statusCode}');
      final reference = '${payload['reference']}';
      final number = '${payload['whatsapp_number']}'.replaceAll(RegExp(r'[^0-9]'), '');
      if (number.isEmpty) throw Exception('Commande $reference enregistrée, mais WhatsApp n’est pas configuré pour cette boutique.');
      final total = payload['amount_total'];
      final currency = payload['currency'];
      final details = items.map((e) => '- ${e.product.name} x${e.quantity}').join('\n');
      final message = 'Bonjour ${widget.store.name}, je souhaite confirmer ma commande $reference.\n$details\nTotal : $total $currency\nNom : $name\nTéléphone : $phone';
      final url = Uri.https('wa.me', '/$number', {'text': message});
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) throw Exception('Commande $reference enregistrée, mais WhatsApp ne s’est pas ouvert.');
      ShopCart.byStore[widget.store.id]?.clear();
      ShopCart.changes.value++;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Commande $reference enregistrée')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally { if (mounted) setState(() => sending = false); }
  }
}

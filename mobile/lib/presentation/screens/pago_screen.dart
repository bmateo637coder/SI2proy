import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/propiedad_model.dart';

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text.replaceAll(' ', '');
    // Limitar a 16 dígitos (4 bloques de 4, estándar internacional)
    if (newText.length > 16) {
      newText = newText.substring(0, 16);
    }
    String formatted = '';
    for (int i = 0; i < newText.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += ' ';
      }
      formatted += newText[i];
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text.replaceAll('/', '');
    if (newText.length > 4) {
      newText = newText.substring(0, 4);
    }
    String formatted = '';
    for (int i = 0; i < newText.length; i++) {
      if (i == 2) {
        formatted += '/';
      }
      formatted += newText[i];
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PagoScreen extends StatefulWidget {
  final PropiedadModel propiedad;

  const PagoScreen({super.key, required this.propiedad});

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _metodoPago = 'tarjeta';
  bool _pagoVerificado = false; // Estado para QR

  Future<void> _verificarPagoQR() async {
    setState(() => _isLoading = true);
    // Simulando verificación con el banco
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _pagoVerificado = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pago verificado exitosamente ✅'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _procesarTransaccion() async {
    if (_metodoPago == 'tarjeta') {
      if (!(_formKey.currentState?.validate() ?? false)) return;
    } else {
      // Si es QR, debe estar verificado antes de continuar
      if (!_pagoVerificado) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor verifica el pago QR primero.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    // Simular procesamiento del banco/pasarela de pagos final (Stripe simulado)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() => _isLoading = false);

    // Navegar al comprobante
    context.pushReplacement('/comprobante', extra: widget.propiedad);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esVenta = widget.propiedad.tipoOperacion.toLowerCase() == 'venta';
    final monto = widget.propiedad.precio;

    return Scaffold(
      appBar: AppBar(
        title: Text(esVenta ? 'Comprar Propiedad' : 'Reservar Alquiler'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Resumen de la transacción
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total a pagar',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${monto.toStringAsFixed(2)}',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.propiedad.titulo, textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Text('Método de Pago', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),

              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'tarjeta',
                    label: Text('Tarjeta Crédito/Débito'),
                    icon: Icon(Icons.credit_card),
                  ),
                  ButtonSegment(
                    value: 'transferencia',
                    label: Text('QR / Transf.'),
                    icon: Icon(Icons.qr_code_2),
                  ),
                ],
                selected: {_metodoPago},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() => _metodoPago = newSelection.first);
                },
              ),

              const SizedBox(height: 24),

              if (_metodoPago == 'tarjeta') ...[
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Número de Tarjeta',
                    prefixIcon: const Icon(Icons.credit_card),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    hintText: '0000 0000 0000 0000',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CardNumberFormatter(),
                  ],
                  validator: (val) {
                    if (val == null || val.replaceAll(' ', '').length < 16) {
                      return 'Se requieren 16 números';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ExpiryDateFormatter(),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Vencimiento (MM/AA)',
                          hintText: 'MM/AA',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (val) {
                          if (val == null ||
                              val.length != 5 ||
                              !val.contains('/')) {
                            return 'Inválido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'CVC',
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (val) =>
                            val != null && val.length >= 3 ? null : 'Requerido',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Nombre del Titular',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (val) =>
                      val != null && val.isNotEmpty ? null : 'Requerido',
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _pagoVerificado
                          ? Colors.green
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Usar un ícono grande como QR falso o una imagen
                      const Icon(
                        Icons.qr_code_2,
                        size: 150,
                        color: Colors.black87,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Escanea este código QR desde tu banca móvil para completar el pago.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 24),
                      if (_pagoVerificado) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 28,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '¡Pago verificado!',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        FilledButton.tonalIcon(
                          onPressed: _isLoading ? null : _verificarPagoQR,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sync),
                          label: const Text('Verificar Pago'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
              FilledButton(
                onPressed: _isLoading ? null : _procesarTransaccion,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirmar y Continuar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

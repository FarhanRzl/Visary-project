import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/brutal.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _login() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      final state = context.read<AppState>();
      if (state.user == null) {
        await state.persistSession(AppUser(
          id: 'u-101',
          name: 'Creator Farhan',
          email: 'farharzl@visary.io',
          quota: QuotaInfo(
            usedMinutes: 12,
            totalMinutes: 60,
            resetAt: DateTime.now().add(const Duration(days: 30)),
            planName: 'Pro Creator',
          ),
        ));
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/dashboard');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VC.bg,
      body: Center(
        child: BBox(
          shadow: 8,
          padding: const EdgeInsets.all(40),
          width: 460,
          color: VC.paper,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: withGaps([
              // Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.rotate(
                    angle: -0.1,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: VC.yellow,
                          border: Border.all(color: VC.ink, width: 3)),
                      child: const Icon(Icons.bolt, size: 26, color: VC.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('VISARY', style: VT.display(30)),
                ],
              ),
              Text('UBAH VIDEO JADI CLIP VIRAL',
                  style: VT.mono(12, color: VC.muted),
                  textAlign: TextAlign.center),

              // Email input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EMAIL', style: VT.mono(11)),
                  const SizedBox(height: 6),
                  BInput(
                    controller: _emailCtrl,
                    hint: 'nama@email.com',
                  ),
                ],
              ),

              // Password input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PASSWORD', style: VT.mono(11)),
                  const SizedBox(height: 6),
                  BInput(
                    controller: _passCtrl,
                    hint: '••••••••••••',
                    obscure: true,
                  ),
                ],
              ),

              // Login button
              BButton(
                label: 'MASUK',
                icon: Icons.login,
                expand: true,
                onTap: _loading ? null : _login,
              ),

              // Divider
              Row(
                children: [
                  const Expanded(child: Divider(color: VC.ink, thickness: 2)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('ATAU', style: VT.mono(11, color: VC.muted)),
                  ),
                  const Expanded(child: Divider(color: VC.ink, thickness: 2)),
                ],
              ),

              // Google auth
              const BButton(
                label: 'MASUK DENGAN GOOGLE',
                icon: Icons.public,
                expand: true,
                kind: BtnKind.outline,
              ),

              // Signup link
              Text(
                'Belum punya akun?  BUAT AKUN',
                style: VT.body(13),
                textAlign: TextAlign.center,
              ),
            ], 24),
          ),
        ),
      ),
    );
  }
}

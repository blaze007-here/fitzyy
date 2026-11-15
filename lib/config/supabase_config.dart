/// One-time Supabase app configuration.
///
/// Paste the values from Supabase Dashboard > Project Settings > API here.
/// Use the Project URL and the public publishable/anon key only.
///
/// Never paste the Supabase service_role key into this file. This file is
/// bundled into the mobile app, so it must never contain a private secret.
class SupabaseConfig {
  const SupabaseConfig._();

  static const url = 'https://oplbdwlepwqxixnlfkyw.supabase.co';
  static const publishableKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wbGJkd2xlcHdxeGl4bmxma3l3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIzMTU5ODIsImV4cCI6MjEwNzg5MTk4Mn0.jOIUOtGp2W9mmbRQohg6c2OZVeRqDnRh5NMkfRQmi2s';
}

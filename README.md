# Passage — E‑Commerce Monorepo (Mobile User App + Seller + Admin Web)

This repository hosts the customer-facing mobile app, a separate seller flow, and a web-only admin console — all in one Flutter project. It is designed to run within DreamFlow for rapid prototyping and testing.

Highlights
- Single codebase with multiple roles: User (buyer), Seller, Admin (web).
- Clean separation of entry points and sessions so credentials do not overlap across roles.
- Local-first storage for demo/testing; no backend is required to try it out.
- Web-only admin console with a seeded admin account for instant login.

Note on backend
- There is no backend connected. To connect Firebase or Supabase later, open the respective panel in DreamFlow and complete setup there. Do not use CLI/manual scripts; DreamFlow handles it for you.


## Contents
- Quick preview in DreamFlow
- Roles and entry points
- Features by role
- Test flows (step-by-step)
- Architecture and storage
- Key files and navigation map
- AI assistant integration (optional)
- Limitations and next steps
- Troubleshooting


## Quick preview in DreamFlow

Mobile user app (default)
- Entry: lib/main.dart
- In DreamFlow, click Run/Preview and choose Mobile (Android/iOS) to open the buyer app.
- You can also preview it in Web — it will still open the user app by default.

Admin web console
- Easiest: Start a normal Web preview and add ?admin=1 to the preview URL, then press Enter.
  - Example: https://your-preview-url/webapp?admin=1
- Dedicated entrypoint alternative: select lib/admin/admin_web_main.dart when launching a Web preview.

Seller flow
- Accessible via links from the user Login and Signup screens: “Seller Sign In” and “Sign up as Seller”.
- These land on independent seller screens and maintain a separate seller session.


## Roles and entry points

- User (buyer)
  - Entry: lib/main.dart boots MyApp
  - Home: LoginScreen -> HomeScreen
- Admin (web-only)
  - Entry: lib/admin/admin_web_main.dart (pure web) OR lib/main.dart (when URL has ?admin=1)
  - Root widget: PassageAdminWebApp
- Seller
  - Launched from buttons on buyer Login/Signup screens
  - Screens: SellerLoginScreen, SellerSignupScreen, SellerDashboardScreen

Role separation at a glance
- User sessions and seller accounts are stored in different places.
- Admin role is checked via LocalAuthStore.role (admin vs user) inside the admin web shell.
- A seller’s credentials won’t sign into the buyer app, and user credentials won’t sign into the seller screens.


## Features by role

User app (buyer)
- Authentication
  - Email/password Login with validation, password visibility toggle
  - Signup with name, email, strong password, confirm password, and terms acceptance
  - Forgot Password placeholder flow
- Shopping
  - Product List and Product Detail with add-to-cart
  - Cart and Checkout (local/demo)
  - Orders history and Order details (local/demo)
  - Reviews model and storage (local/demo)
- Account & preferences
  - Profile editing (name, username, contact, etc.)
  - Addresses management
  - Payment methods (local/demo)
  - Privacy & security (2FA toggle placeholders, app lock, session list demo)
  - Notifications center + notification preferences (local/demo)
- Engagement & UX
  - Points system placeholder and a simple Games Hub/Tap Challenge mini-game
  - Floating draggable AI assistant button across screens
  - Light/Dark theme with Material 3 and Google Fonts

Seller
- Independent seller authentication
  - Separate signup with name, optional store name, email, strong password
  - Separate login that verifies only seller accounts
  - Dedicated seller session (not shared with buyer app)
- Seller dashboard shell
  - Tabs for Overview, Orders, Account (placeholders ready to extend)
  - Sign out clears only seller session

Admin (web)
- Web-only Admin login
  - Seeded admin account for immediate testing: admin@passage.app / Admin@123
  - On login, role is set to admin (LocalAuthStore) and routed to AdminRootScreen
- Admin dashboard shell
  - Basic scaffold and logout resets role to user
  - Ready to extend with Products, Orders, Users, and more


## Test flows (step-by-step)

User app
1) Open lib/main.dart and run Mobile preview (or Web preview without admin flag).
2) Signup: Create a new account; you’ll be routed to Home on success.
3) Login: Use the email/password you just set; navigate to Home.
4) Explore: Add items to cart, open checkout, edit profile, manage addresses, etc.

Seller
1) From Login or Signup screens, click the seller link in the footer.
2) Create a seller account via SellerSignupScreen OR use SellerLoginScreen if already created.
3) You’ll land in SellerDashboardScreen with tabs (Overview, Orders, Account).
4) Logout from the AppBar; this only clears the seller session.

Admin web console
Option A (no entry switch):
- Start Web preview, then append ?admin=1 to the preview URL and reload.

Option B (dedicated entry):
- Choose lib/admin/admin_web_main.dart as the web entrypoint when starting a Web preview.

Login credentials
- Admin: admin@passage.app / Admin@123 (seeded locally on first use)
- Buyer/Seller: Create your own via their respective signup screens.


## Architecture and storage

Local-first storage (no backend)
- Buyer auth state: lib/services/local_auth_store.dart
  - Stores email, password hash, sessions, and a simple role field (user/admin)
- Buyer profile: lib/services/local_user_profile_store.dart
- Cart, orders, products, payment methods, notifications, points, etc.: lib/services/*
- Seller accounts and session: lib/services/local_seller_accounts_store.dart
- Admin accounts: lib/services/local_admin_accounts_store.dart (with a seeded admin)

Admin switching logic
- lib/main.dart checks the web URL. If running on Web and it sees ?admin=1 or an /admin path, it runs PassageAdminWebApp instead of the user app.
- For a pure admin deployment, lib/admin/admin_web_main.dart is a standalone entry for web.


## Key files and navigation map

Entries
- lib/main.dart — user app entry (and URL-switch for admin on web)
- lib/admin/admin_web_main.dart — admin-only web entry

User app (selected)
- lib/screens/login_screen.dart — login with links to Signup and Seller
- lib/screens/signup_screen.dart — buyer signup with seller signup link
- lib/screens/home_screen.dart — user home
- lib/screens/cart_screen.dart — cart
- lib/screens/checkout_screen.dart — checkout
- lib/screens/orders_screen.dart — orders
- lib/screens/product_detail_screen.dart — product details
- lib/screens/edit_profile_screen.dart — profile editing
- lib/screens/addresses_screen.dart — addresses
- lib/screens/payment_methods_screen.dart — payment methods
- lib/screens/privacy_security_screen.dart — privacy & security
- lib/screens/notifications_screen.dart — notifications
- lib/screens/notification_settings_screen.dart — notification prefs
- lib/screens/games_hub_screen.dart, lib/screens/tap_challenge_screen.dart — mini-games
- lib/screens/ai_assistant_screen.dart — AI assistant screen

Seller
- lib/seller/seller_signup_screen.dart, lib/seller/seller_login_screen.dart
- lib/seller/seller_dashboard_screen.dart

Admin (web)
- lib/admin/admin_app.dart — MaterialApp wrapper for admin
- lib/admin/admin_login_screen.dart — admin login
- lib/admin/admin_root.dart — checks role and routes to admin dashboard
- lib/admin/admin_dashboard_screen.dart — admin dashboard shell

Theme
- lib/theme.dart — Light/Dark ThemeData with Material 3 + Google Fonts


## AI assistant integration (optional)

- Client: lib/openai/openai_config.dart
  - Uses environment-provided OPENAI_PROXY_API_KEY and OPENAI_PROXY_ENDPOINT.
  - DreamFlow injects these when you enable the OpenAI integration in the UI.
- To enable AI:
  - Open the OpenAI panel in DreamFlow and switch it on. No code changes are needed.


## Limitations and next steps

- All data is local (SharedPreferences). It is suitable for demos and UI flows, not production.
- Payments, orders, inventory, and reviews are mock/local. Wire them to a backend before going live.
- Admin and Seller UIs are shells for now. Extend with product CRUD, order management, payouts, analytics, etc.
- Search, filtering, and product images are placeholders; integrate real data or a CMS.

Suggested next steps
- Connect Firebase or Supabase via the DreamFlow panel (auth, products, orders, notifications).
- Add role-based routes and guards backed by server auth.
- Implement product CRUD for sellers and admins.
- Implement real checkout and payment gateway integration.
- Add analytics and audit trails for admin actions.


## Troubleshooting

- I see the user app when I preview on web.
  - Append ?admin=1 to the preview URL to switch to the admin console.
  - Or launch using lib/admin/admin_web_main.dart.

- Seller credentials can’t log in on the buyer login screen.
  - This is expected. Seller accounts are separate by design. Use the Seller Sign In screen.

- I want to connect a backend.
  - Open the Firebase or Supabase panel in DreamFlow and follow the guided setup. The project will be configured automatically.


## Credits
- Built with Flutter (Material 3) in DreamFlow.
- Typography via Google Fonts.

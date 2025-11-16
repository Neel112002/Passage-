# Firebase Integration Guide

This document explains how to use Firebase in your Passage e-commerce app.

## 🔥 What's Been Set Up

Your project now has complete Firebase integration with:

### 1. **Firebase Configuration Files**
- `firebase.json` - Firebase project configuration
- `firestore.rules` - Security rules for Firestore database
- `firestore.indexes.json` - Query indexes for optimal performance

### 2. **Data Models with Firestore Support**
All models now include:
- `createdAt` and `updatedAt` timestamps
- `userId` fields for ownership tracking
- Firestore `Timestamp` conversion in `toMap()` and `fromMap()`

Updated models:
- `AdminProductModel` - Products with timestamps
- `OrderItemModel` - Orders with user ownership
- `ProductReview` - Reviews with user ownership
- `UserProfile` - User profiles with timestamps

### 3. **Firestore Services**
New service classes that interact with Firebase:

- `FirestoreProductsService` - Product CRUD operations
- `FirestoreReviewsService` - Review management
- `FirestoreOrdersService` - Order management
- `FirestoreUserProfileService` - User profile management
- `FirebaseAuthService` - Authentication wrapper

### 4. **Firebase Initialization**
- Firebase is initialized in `main.dart` on app startup
- All dependencies are added to `pubspec.yaml`

---

## 📋 Before You Start

### **IMPORTANT: Enable Authentication**

You **MUST** enable Email/Password authentication in your Firebase Console:

1. Go to: https://console.firebase.google.com/u/0/project/som7ukrvvpx1vwk6dvlufr0fj581om/authentication/providers
2. Click on "Email/Password" provider
3. Enable it and save

Without this step, users won't be able to sign up or sign in!

### **Deploy Security Rules**

After enabling authentication:

1. Open the Firebase panel in the left sidebar of Dreamflow
2. Check the deployment status
3. If rules aren't deployed, follow the instructions in the Firebase panel

---

## 🚀 How to Use Firebase Services

### **Authentication**

```dart
import 'package:passage/services/firebase_auth_service.dart';

// Sign up
await FirebaseAuthService.signUpWithEmail(
  email: 'user@example.com',
  password: 'password123',
  displayName: 'John Doe',
);

// Sign in
await FirebaseAuthService.signInWithEmail(
  email: 'user@example.com',
  password: 'password123',
);

// Sign out
await FirebaseAuthService.signOut();

// Check if signed in
bool isSignedIn = FirebaseAuthService.isSignedIn;

// Get current user ID
String? userId = FirebaseAuthService.currentUserId;
```

### **Products**

```dart
import 'package:passage/services/firestore_products_service.dart';

// Load all products
List<AdminProductModel> products = await FirestoreProductsService.loadAll();

// Load by category
List<AdminProductModel> electronics = await FirestoreProductsService.loadByCategory('Electronics');

// Load by tag
List<AdminProductModel> trending = await FirestoreProductsService.loadByTag('Trending');

// Get single product
AdminProductModel? product = await FirestoreProductsService.getById('product-id');

// Add/update product
await FirestoreProductsService.upsert(product);

// Delete product
await FirestoreProductsService.remove('product-id');

// Real-time updates
Stream<List<AdminProductModel>> productsStream = FirestoreProductsService.watchAll();

// Seed sample data (first run only)
await FirestoreProductsService.seedSampleData();
```

### **Orders**

```dart
import 'package:passage/services/firestore_orders_service.dart';

// Load user's orders
List<OrderItemModel> orders = await FirestoreOrdersService.loadAll();

// Load by status
List<OrderItemModel> processing = await FirestoreOrdersService.loadByStatus(OrderStatus.processing);

// Create order
String? orderId = await FirestoreOrdersService.create(order);

// Update order status
await FirestoreOrdersService.updateStatus(orderId, OrderStatus.shipped);

// Real-time updates
Stream<List<OrderItemModel>> ordersStream = FirestoreOrdersService.watchAll();
```

### **Reviews**

```dart
import 'package:passage/services/firestore_reviews_service.dart';

// Load reviews for a product
List<ProductReview> reviews = await FirestoreReviewsService.loadByProduct('product-id');

// Add review (user must be signed in)
await FirestoreReviewsService.add(review);

// Update review
await FirestoreReviewsService.update(review);

// Delete review
await FirestoreReviewsService.remove('review-id');

// Get average rating
double avgRating = await FirestoreReviewsService.getAverageRating('product-id');

// Real-time updates
Stream<List<ProductReview>> reviewsStream = FirestoreReviewsService.watchByProduct('product-id');
```

### **User Profiles**

```dart
import 'package:passage/services/firestore_user_profile_service.dart';

// Load current user's profile
UserProfile? profile = await FirestoreUserProfileService.load();

// Load any user's profile
UserProfile? otherProfile = await FirestoreUserProfileService.getById('user-id');

// Save profile
await FirestoreUserProfileService.save(profile);

// Update specific fields
await FirestoreUserProfileService.updateFields({
  'phone': '+1234567890',
  'bio': 'New bio text',
});

// Real-time updates
Stream<UserProfile?> profileStream = FirestoreUserProfileService.watch();
```

---

## 🔐 Security Rules

The security rules ensure:

1. **Private Data**: Users can only access their own orders, profiles, cart items, addresses, and payment methods
2. **Public Data**: Products and reviews are readable by everyone
3. **Authenticated Writes**: Only signed-in users can create/update content
4. **Owner-Only Edits**: Users can only edit/delete their own reviews and orders

---

## 📊 Firestore Collections Structure

```
/products/{productId}
  - All product data
  - Public read, authenticated write

/orders/{orderId}
  - Order data with userId field
  - Private to owner

/reviews/{reviewId}
  - Review data with userId field
  - Public read, owner write

/users/{userId}
  - User profile data
  - Private to owner

/users/{userId}/cart/{cartItemId}
  - Sub-collection for cart items
  - Private to owner

/users/{userId}/addresses/{addressId}
  - Sub-collection for addresses
  - Private to owner

/users/{userId}/payment_methods/{paymentId}
  - Sub-collection for payment methods
  - Private to owner
```

---

## 🔄 Migration from Local Storage

Your existing local storage services are still intact:
- `LocalProductsStore`
- `LocalOrdersStore`
- `LocalReviewsStore`
- etc.

To migrate:

1. Replace imports in your screens/widgets
2. Update method calls (API is similar but slightly different)
3. Handle authentication state (Firebase requires signed-in users)

Example:
```dart
// Before
import 'package:passage/services/local_products_store.dart';
final products = await LocalProductsStore.loadAll();

// After
import 'package:passage/services/firestore_products_service.dart';
final products = await FirestoreProductsService.loadAll();
```

---

## ⚠️ Important Notes

1. **Authentication Required**: Most Firebase operations require a signed-in user
2. **Error Handling**: Always wrap Firebase calls in try-catch blocks
3. **Real-time Updates**: Use `Stream` methods (`watch*`) for real-time UI updates
4. **Indexes**: If you see index errors, click the provided link to create the index
5. **Rules Deployment**: Security rules must be deployed via Firebase panel
6. **Network Required**: Firebase requires an internet connection

---

## 🎯 Next Steps

1. **Enable Authentication** in Firebase Console (see link above)
2. **Deploy Security Rules** via Firebase panel
3. **Test Sign Up/Sign In** flows
4. **Seed Sample Data** using `FirestoreProductsService.seedSampleData()`
5. **Update Your Screens** to use Firebase services
6. **Test Real-time Updates** with `watch*` methods

---

## 🆘 Troubleshooting

### "Missing or insufficient permissions"
- Check that security rules are deployed
- Verify user is signed in for protected operations
- Check the security rules in `firestore.rules`

### "The query requires an index"
- Click the provided link in the error message
- Wait for index creation (can take a few minutes)
- Don't create alternative solutions - just wait for the index

### Authentication errors
- Verify Email/Password auth is enabled in Firebase Console
- Check error messages from `FirebaseAuthService` for details
- See https://console.firebase.google.com/u/0/project/som7ukrvvpx1vwk6dvlufr0fj581om/authentication/providers

---

## 📚 Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase Authentication](https://firebase.google.com/docs/auth)

---

**Your Firebase integration is ready! Follow the steps above to start using cloud-based data storage and authentication.** 🚀

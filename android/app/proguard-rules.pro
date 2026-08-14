# Flutter supplies its own rules through the Gradle plugin; this file is for
# what the app itself pulls in.

# The Mobile Ads SDK and the consent SDK reflect over their own classes.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }

# WorkManager and Room arrive transitively with play-services-ads-api. Room
# generates its database implementation as <Name>_Impl and instantiates it by
# reflecting on that name, so R8 sees no reference to the class and deletes it.
#
# The failure is invisible at build time and total at run time: the release
# build died on launch with "Failed to create an instance of
# androidx.work.impl.WorkDatabase", from a ContentProvider that runs before any
# Flutter code. Nothing in the Dart layer or the test suite can catch this —
# only installing a real release build does.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.** { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# MainActivity is named in AndroidManifest.xml, so it must survive by name.
-keep class safarnamastudios.meribiodata.app.MainActivity { *; }

# Google Sign-In, and the Drive authorisation it grants.
#
# Same failure as the Room case above, in a different library, and it cost a day
# to find because the symptom pointed somewhere else entirely: sign-in worked on
# a debug build and failed on the Play build, which looks exactly like a signing
# certificate mismatch. It was not. Debug builds are not minified; release
# builds are, and R8 was stripping the auth path.
#
# google_sign_in 7.x on Android goes through Credential Manager and Google
# Identity Services, both of which resolve classes reflectively and read generic
# signatures off them. R8 removes what it cannot see referenced, the account
# chooser still appears because that is a system UI, and only the token and
# scope grant fail — so the app gets an account and no authorisation, and shows
# the Connect button again.
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }
-keep class androidx.credentials.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn androidx.credentials.**

# Reflection over generics and annotations needs these kept globally; without
# Signature in particular, parameterised types come back as raw and the
# identity libraries fail to deserialise their own responses.
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod

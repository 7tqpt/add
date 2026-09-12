// **ويُستورَد `Properties` ولا يُكتب مؤهَّلاً.** كتبتُ `java.util.Properties()`
// أوّلَ مرّة فسقط البناءُ بـ«Unresolved reference 'util'»: في سكربت Gradle
// بلغة Kotlin يعرف الاسمُ `java` **امتدادَ مشروعِ Java** لا حزمةَ اللغة، فيحجب
// الحزمةَ عن أن تُقرأ مؤهَّلةً. ولا يُمسك هذا محلّلٌ ولا اختبار — يُمسكه بناءٌ
// حقيقيّ، وقد أُطلق على الفرع قبل الدمج لهذا بعينه.
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// إضافة Google Services تُطبَّق **إن وُجد الملف فقط**.
//
// وهذا هو ما يجعل الدفع اختيارياً: `google-services.json` يخرج من مشروع
// Firebase الخاص بالمالك، ولا وجود له في المستودع (ولا ينبغي). ولو طُبِّقت
// الإضافة بلا الملف لأسقطت البناء كلَّه برسالة
// «File google-services.json is missing» — فيتعطّل بناء الحزمة عند كل من
// استنسخ المشروع، بسبب ميزةٍ لم يطلبها بعد.
//
// فمن أراد الدفع وضع الملف في `android/app/` وأعاد البناء، ولا شيء غير ذلك.
val googleServices = file("google-services.json").exists()
if (googleServices) {
    apply(plugin = "com.google.gms.google-services")
}

// ــــ مفتاحُ التوقيع ــــــــــــــــــــــــــــــــــــــــــــــــــــــــــ
//
// **هويّةُ التطبيق في أندرويد هي توقيعُه لا اسمُه.** وكان البناءُ يوقّع
// بمفتاح التنقيح — وهذا المفتاحُ **يُخلَق جديداً على كلّ آلةِ بناء**. فحزمةُ
// كلّ جولةٍ تخرج بهويّةٍ أخرى، ومن ثبّت السابقةَ لا يستطيع تثبيتَ التاليةَ
// فوقها: يردّها النظامُ لاختلاف التوقيع، فيحذف التطبيقَ ويفقد ما فيه. ومع
// ذلك تردّها Google Play أصلاً.
//
// **ويُقرأ الملفُّ ولا يُشترَط.** لو أُسقط البناءُ عند غيابه لَانكسر عند كلّ
// من استنسخ المشروعَ ولم يُنشئ مفتاحاً بعد — وهي الحجّةُ نفسُها التي بها
// صار `google-services.json` اختياريّاً فوقه. فبلا الملفِّ يبقى مفتاحُ
// التنقيح كما كان، ومعه تُوقَّع الحزمةُ بمفتاح صاحبها.
//
// والملفُّ مُهمَلٌ في `.gitignore` قبل أن يوجد، وموضعُه `android/key.properties`:
//
//   storeFile=/المسار/المطلق/إلى/farhati.jks
//   storePassword=…
//   keyAlias=farhati
//   keyPassword=…
val keyPropsFile = rootProject.file("key.properties")
val keyProps = Properties().apply {
    if (keyPropsFile.exists()) keyPropsFile.inputStream().use { load(it) }
}

// **وسطرٌ ناقصٌ يُسمّى.** بلا هذا يعيد `getProperty` فراغاً فيسقط البناءُ
// بـ`NullPointerException` في عمق AGP — ومن كتب الملفَّ بيده وسها عن سطرٍ لا
// يفهم من الرسالة أنّ علّتَه سطرٌ سها عنه.
fun keyProp(name: String): String =
    keyProps.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException(
            "android/key.properties موجودٌ ولا سطرَ «$name» فيه. " +
                "الأسطرُ الأربعةُ مكتوبةٌ في mobile/android/SIGNING.md.",
        )

android {
    namespace = "ye.aras.aras"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ye.aras.aras"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyPropsFile.exists()) {
            create("release") {
                storeFile = file(keyProp("storeFile"))
                storePassword = keyProp("storePassword")
                keyAlias = keyProp("keyAlias")
                keyPassword = keyProp("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // بمفتاح صاحبها إن وُجد، وبمفتاح التنقيح إن لم يوجد — والحجّةُ
            // مكتوبةٌ عند قراءة `key.properties` أعلاه.
            signingConfig = signingConfigs.getByName(
                if (keyPropsFile.exists()) "release" else "debug",
            )

            // R8 وتقليمُ الموارد.
            //
            // **ولماذا لم تكونا مفعّلتين:** قالب Flutter يخرج بهما مطفأتين،
            // فتُشحن أصنافُ Firebase وخدمات Google والإضافات كلُّها كما هي —
            // بما لا يُستدعى منها أبداً. وحزمةُ ARM64 كانت ٢٣٫٧ م.ب.
            //
            // وهذا يُقاس في البناء لا يُخمَّن هنا: سطرُ «الحزمة» في ملخّص
            // التشغيل يقول الرقم بعد كل بناء، وحارسُ السقف يُسقط البناء إن
            // عادت تسمن.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

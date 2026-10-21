# 1ST MARKET

متجر عربي RTL بـ HTML وCSS وJavaScript، وصفحة إدارة منفصلة على `admin.html`. تسجيل العميل بالبريد وكلمة المرور أو Google فقط. يدعم عناوين متعددة، موقع GPS، سجل الطلبات، طلب الدفع عند الاستلام مع الفكة، ودور دليفري منفصل في لوحة الإدارة. خيار البطاقة والمحفظة يظل مقفولًا إلى أن تربط بوابة دفع مرخصة.

## إعداد Supabase لأول مرة

1. أنشئ مشروع Supabase وافتح SQL Editor.
2. شغّل كامل ملف `schema.sql`. الملف ينشئ جداول المنتجات والأقسام والطلبات وإعدادات المتجر والسلايد شو، ومساحة الصور `market-media` مع سياسات الحماية.
3. من Project Settings → API انسخ Project URL وPublishable/anon key وضعهما في `config.js`. لا تضع `service_role` key في أي ملف من ملفات الموقع.
4. من Authentication → Users أنشئ حساب الإدارة. بعد ذلك شغّل في SQL Editor الأمر التالي، مع تغيير البريد:

```sql
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
where email = 'admin@example.com';
```

5. افتح `admin.html` وسجّل الدخول. لا تفعّل تسجيلًا عامًا للمسؤولين؛ سياسات قاعدة البيانات تسمح بالتعديل لحساب يحمل `app_metadata.role = admin` فقط.

## حسابات العملاء والدفع

- البريد وكلمة المرور يعملان من Supabase Auth. قد يحتاج الحساب الجديد لتأكيد البريد من الرسالة.
- لتفعيل تسجيل Google: في Supabase افتح Authentication → Sign In / Providers → Google وانسخ Callback URL الظاهر هناك. في Google Cloud Console أنشئ OAuth Client ID من النوع Web application؛ ضع أصل موقعك مثل `https://username.github.io` في Authorized JavaScript origins، وضع Callback URL الخاص بـ Supabase في Authorized redirect URIs. انسخ Client ID وClient Secret إلى إعداد Google في Supabase، ثم من Authentication → URL Configuration ضع رابط GitHub Pages الكامل مثل `https://username.github.io/repository/` في Site URL وأضفه إلى Redirect URLs. لا تضع Client Secret في ملفات الموقع. [الدليل الرسمي من Supabase](https://supabase.com/docs/guides/auth/social-login/auth-google).
- تسجيل الهاتف وOTP غير مستخدم في واجهة العميل.
- تشغيل `schema.sql` بعد تحديثه مطلوب لتخزين `user_id` وطريقة الدفع والفكة، ولمنع إنشاء طلبات جديدة بدون حساب. عمود `user_id` يسمح ببقاء الطلبات القديمة بدون مستخدم، لكن سياسة RLS الجديدة تمنع الطلبات المجهولة الجديدة.
- أزرار Visa والمحفظة لا تنفّذ خصمًا حقيقيًا. تحتاج حساب تاجر وبوابة مناسبة لبلدك، وتكامل دفع من خلال Supabase Edge Function أو خادم آمن. لا تضع مفاتيح بوابة الدفع السرية في `store.js` أو GitHub.

## الإشعارات والصوت

- يطلب الموقع إذن الإشعارات بعد رسالة موافقة، ويمكن للعميل تشغيلها من القائمة. إذن المتصفح وحده لا يسمح بإرسال إشعار والمتصفح مغلق.
- حل مجاني مبدئي للإشعارات: Firebase Cloud Messaging للويب، مع استضافة HTTPS. أنشئ Firebase project، فعّل Cloud Messaging، أنشئ VAPID key، ثم أضف `firebase-messaging-sw.js` وتهيئة Firebase ورمز استقبال الإشعار. الإرسال من لوحة الإدارة يحتاج خادمًا آمنًا (مثل Supabase Edge Function) يحمل بيانات الاعتماد السرية؛ لا تحفظها في المتصفح. [دليل FCM للويب](https://firebase.google.com/docs/cloud-messaging/web/get-started) يوضح HTTPS وVAPID وservice worker.
- في النسخة الحالية يظهر للعميل سؤال موافقة واضح للإشعارات عند أول زيارة، وتصدر نغمة قصيرة عند قبول الطلب. لوحة الإدارة تفحص الطلبات كل 12 ثانية وتعرض إشعارًا داخل الصفحة؛ فعّل زر «تفعيل صوت الطلبات» بعد فتح لوحة الإدارة. إذن المتصفح وحده لا يرسل إشعارات فعلية للعملاء؛ الإرسال يحتاج إعداد FCM الخادمي المذكور أعلاه.
- لا تختبر الإشعارات أو تسجيل Google من `file:///`. انشر على GitHub Pages أو استخدم localhost؛ Web Push يحتاج HTTPS (localhost استثناء للتطوير).

## الصور والسلايد شو

من صفحة الإدارة افتح «المنتجات والتفاصيل»، ارفع عدة صور للمنتج، واختر صورة رئيسية وباقي الصور تظهر كصور تفاصيل. املأ العلامة التجارية والحجم والمنشأ والمكونات والتخزين وتاريخ الانتهاء والسعر والخصم والمخزون والوصف. الصور تُرفع إلى Supabase Storage وتظهر مباشرة في المتجر.

من «السلايد شو» أضف شرائح بصورة وعنوان ووصف وزر، غيّر ترتيبها أو أخفها أو احذفها. الشرائح النشطة تتبدل تلقائيًا أعلى الصفحة الرئيسية.

من «إعدادات المتجر» ارفع لوجو PNG/JPG/WebP واضغط حفظ. العميل يختار أكثر من عنوان من «حسابي ← عناويني»، ويمكنه أثناء الطلب اختيار عنوان محفوظ أو تحديد GPS/مشاركة الموقع. يحتاج GPS إذن المستخدم وموقعًا آمنًا HTTPS أو localhost. الدليفري يفتح خرائط Google من الطلب ويختار «ابدأ الطريق».

## إعداد حساب الدليفري

أنشئ مستخدمًا ببريد وكلمة مرور من Supabase → Authentication → Users، ثم استبدل البريد في هذا الأمر وشغّله في SQL Editor:

```sql
update auth.users
set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"delivery"}'::jsonb
where email = 'delivery@example.com'
returning email, raw_app_meta_data->>'role' as role;
```

بعدها يفتح السائق `admin.html` ويسجل ببريده وكلمة مروره؛ ستظهر له واجهة الدليفري فقط. للإسناد من تبويب الطلبات، اضغط «إسناد للدليفري» والصق UID السائق من Authentication → Users. أضف رقم هاتف السائق إلى حسابه في Supabase Auth Users لكي يظهر زر الاتصال برقم السائق للعميل عند خروج الطلب للتوصيل؛ رقم إعدادات المتجر يبقى رقمًا احتياطيًا. شغّل `schema.sql` المحدّث لتفعيل عناوين العملاء وحقول GPS وسياسات الطلبات.

## حسابات الفريق والشات

لوحة «حسابات الفريق» تنشئ حساب مسؤول أو دليفري وتعرض الاسم والبريد والهاتف والمركبة واللوحة وUID. الإنشاء يتم من Edge Function آمنة لأن Admin Auth API لا يجوز تشغيله من المتصفح. انشر `supabase/functions/manage-team-user/index.ts` إلى مشروعك باسم `manage-team-user` باستخدام Supabase CLI بعد `supabase login` و`supabase link --project-ref YOUR_PROJECT_REF` ثم `supabase functions deploy manage-team-user`. وظيفة Supabase تستخدم مفاتيح البيئة الخادمية تلقائيًا؛ لا تضع `service_role` في `config.js` أو GitHub. [مرجع Supabase لإنشاء مستخدم إداري](https://supabase.com/docs/reference/javascript/auth-admin-createuser) يوضح أن هذه العملية مخصصة للخادم.

بعد تشغيل `schema.sql`، تظهر محادثة مجانية مرتبطة بالطلب بين العميل والدليفري الذي استلمه، وتتحدث الرسائل تلقائيًا كل بضع ثوانٍ. زر الاتصال يفتح اتصال الهاتف المعتاد في جهاز العميل؛ مكالمة صوتية داخل صفحة الويب تحتاج بنية WebRTC واتصال ترحيل TURN أو مزود اتصالات، لذلك لا تدّعي النسخة الحالية أنها مكالمة مجانية داخل المتصفح.

## النشر عبر GitHub Pages

ارفع ملفات المشروع إلى GitHub، ثم Settings → Pages، واختر النشر من الفرع الرئيسي ومجلد الجذر. انشر `index.html` و`admin.html` مع الملفات الأخرى في نفس المجلد. صفحة الإدارة مستقلة ومحميّة بتسجيل دخول Supabase، ولا يوجد رابط لها في تنقل العملاء.

## تنبيه قبل الإطلاق

لا يوجد لدي وصول تلقائي إلى حساب Supabase أو ChatGPT الخاص بك. أقدر أكمل إعداد الملفات، لكن الاتصال الفعلي يحتاج Project URL وanon key (المفتاح العام فقط) أو أن تضعهما بنفسك في `config.js`. لا ترسل كلمة المرور أو service role key. نسخة المتجر التجريبية تعمل من دون Supabase، لكن رفع الصور والبيانات المشتركة والداشبورد تحتاج إعداد المشروع.

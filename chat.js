(() => {
  const esc = (s='') => String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  let timer = null, busy = false;
  async function open(db, session, orderId, asDelivery = false) {
    if (!db || !session) return;
    close();
    const root=document.createElement('div');root.id='market-chat-modal';root.className='chat-overlay';
    root.innerHTML=`<section class="chat-panel" role="dialog" aria-modal="true" aria-label="محادثة الطلب"><header><div><small>1ST MARKET</small><h2>محادثة الطلب</h2></div><button type="button" data-chat-close aria-label="إغلاق">×</button></header><div class="chat-feed" id="market-chat-feed"><p class="chat-empty">جار تحميل الرسائل…</p></div><form id="market-chat-form"><input class="field" name="body" maxlength="2000" required placeholder="اكتب رسالتك…"><button class="red-button">إرسال</button></form><small class="chat-footnote">الرسائل مرتبطة بالطلب وتظهر لصاحبه والسائق المسند إليه فقط.</small></section>`;
    document.body.append(root);
    const feed=root.querySelector('#market-chat-feed');
    async function refresh(){if(busy||!document.body.contains(root))return;busy=true;const {data,error}=await db.from('order_messages').select('*').eq('order_id',orderId).order('created_at',{ascending:true});busy=false;if(error){feed.innerHTML='<p class="chat-empty">تعذر تحميل المحادثة. تأكد من تشغيل schema.sql المحدّث.</p>';return}feed.innerHTML=data?.length?data.map(m=>`<article class="chat-message ${m.sender_id===session.user.id?'mine':''}"><small>${m.sender_id===session.user.id?'أنت':asDelivery?'العميل':'مندوب التوصيل'} · ${new Date(m.created_at).toLocaleTimeString('ar-EG',{hour:'2-digit',minute:'2-digit'})}</small><p>${esc(m.body)}</p></article>`).join(''):'<p class="chat-empty">ابدأ المحادثة مع الطرف الآخر.</p>';feed.scrollTop=feed.scrollHeight}
    root.addEventListener('click',e=>{if(e.target.closest('[data-chat-close]')||e.target===root)close()});
    root.querySelector('#market-chat-form').addEventListener('submit',async e=>{e.preventDefault();const input=e.currentTarget.elements.body,body=input.value.trim();if(!body)return;input.disabled=true;const {error}=await db.from('order_messages').insert({order_id:orderId,sender_id:session.user.id,body});input.disabled=false;if(error){alert('تعذر إرسال الرسالة. تأكد من تشغيل schema.sql.');return}input.value='';await refresh()});
    await refresh();timer=setInterval(refresh,4000);root.querySelector('input').focus();
  }
  function close(){if(timer)clearInterval(timer);timer=null;document.querySelector('#market-chat-modal')?.remove()}
  window.marketChat={open,close};
})();

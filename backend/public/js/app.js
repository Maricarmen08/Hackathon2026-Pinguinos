function getActiveBusinessId() {
  return Number(localStorage.getItem('khipu_negocio_id') || 1);
}

function showToast(text) {
  const el = document.getElementById('toastBox');
  const txt = document.getElementById('toastText');
  if (!el || !txt) return;
  txt.textContent = text;
  el.style.display = 'flex';
  setTimeout(() => {
    el.style.display = 'none';
  }, 2500);
}

async function fetchHeaderBusiness() {
  const id = getActiveBusinessId();
  const res = await fetch(`/api/negocio/${id}`);
  const biz = await res.json();
  const nameEl = document.getElementById('headerBizName');
  const ownerEl = document.getElementById('headerOwnerName');
  const avatarEl = document.getElementById('headerAvatar');

  if (biz && biz.nombre_negocio) {
    if (nameEl) nameEl.textContent = biz.nombre_negocio;
    if (ownerEl) ownerEl.textContent = `Hola, ${biz.propietario || 'Comerciante'}`;
    if (avatarEl && biz.propietario) {
      const parts = biz.propietario.trim().split(' ');
      const initials = parts.length > 1
        ? parts[0][0] + parts[1][0]
        : parts[0].slice(0, 2);
      avatarEl.textContent = initials.toUpperCase();
    }
  }
  return biz;
}

function parseNaturalText(text, source) {
  const lower = text.toLowerCase();
  const isExpense =
    source === 'FOTO_BOLETA' ||
    lower.includes('pagu') ||
    lower.includes('compr') ||
    lower.includes('gast') ||
    lower.includes('proveedor') ||
    lower.includes('boleta') ||
    lower.includes('luz');

  const nums = text.match(/(\d+(\.\d+)?)/g);
  const amount = nums ? parseFloat(nums[nums.length - 1]) : 24.0;

  let category = isExpense ? 'Proveedores' : 'Venta mostrador';
  if (
    lower.includes('aceite') ||
    lower.includes('arroz') ||
    lower.includes('leche') ||
    lower.includes('azucar') ||
    lower.includes('azúcar')
  ) {
    category = 'Abarrotes';
  } else if (lower.includes('gaseosa') || lower.includes('agua')) {
    category = 'Bebidas';
  } else if (lower.includes('luz') || lower.includes('servicio')) {
    category = 'Servicios';
  }

  let cleanTitle = text
    .replace(/vend[ií]\s*/i, '')
    .replace(/pagu[eé]\s*/i, '')
    .replace(/compr[eé]\s*/i, '')
    .replace(/\s*(a|por)\s*\d+(\.\d+)?\s*(soles)?/i, '')
    .trim();

  if (!cleanTitle) cleanTitle = isExpense ? 'Compra de mercadería' : 'Venta del día';
  if (cleanTitle.length > 26) cleanTitle = cleanTitle.slice(0, 26);
  cleanTitle = cleanTitle.charAt(0).toUpperCase() + cleanTitle.slice(1);

  return {
    negocio_id: getActiveBusinessId(),
    tipo: isExpense ? 'GASTO' : 'INGRESO',
    concepto: cleanTitle,
    categoria: category,
    monto: amount,
    origen_ia: source,
    prompt_original: text
  };
}


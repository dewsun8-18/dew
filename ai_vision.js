/**
 * AI Vision & Image-to-Dashboard Module for Meatball Store Dashboard
 * Connects with Local PowerShell Server and Google Gemini API
 */

(function () {
  // State
  let config = {
    apiKey: '',
    model: 'gemini-3.5-flash-lite',
    hasApiKey: false,
    serverAvailable: false
  };

  let uploadQueue = []; // Array of { file, base64, mimeType, status, result, error }
  let activeIndex = 0;
  let zoomLevel = 1;
  let rotation = 0;

  // Initialize once DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initAiVision);
  } else {
    initAiVision();
  }

  async function initAiVision() {
    injectModals();
    await checkServerAndConfig();
  }

  // Check backend server and config
  async function checkServerAndConfig() {
    try {
      const res = await fetch('/api/config');
      if (res.ok) {
        const data = await res.json();
        config.serverAvailable = true;
        config.hasApiKey = data.hasApiKey;
        config.model = data.model || 'gemini-3.5-flash-lite';
        config.maskedKey = data.maskedKey || '';
        updateStatusBadge(true);
      } else {
        fallbackToLocalStorage();
      }
    } catch (e) {
      fallbackToLocalStorage();
    }
  }

  function fallbackToLocalStorage() {
    config.serverAvailable = false;
    const localKey = localStorage.getItem('gemini_api_key') || '';
    config.apiKey = localKey;
    config.hasApiKey = !!localKey;
    config.model = localStorage.getItem('gemini_model') || 'gemini-3.5-flash-lite';
    updateStatusBadge(false);
  }

  function updateStatusBadge(isOnline) {
    let badge = document.getElementById('aiServerStatusBadge');
    if (!badge) {
      const navContainer = document.querySelector('header .max-w-7xl');
      if (navContainer) {
        badge = document.createElement('div');
        badge.id = 'aiServerStatusBadge';
        badge.className = 'hidden sm:flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-medium transition';
        const brandArea = navContainer.querySelector('.truncate');
        if (brandArea) brandArea.appendChild(badge);
      }
    }
    if (badge) {
      if (isOnline) {
        badge.className = 'hidden sm:inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[11px] font-medium bg-emerald-50 text-emerald-700 border border-emerald-200';
        badge.innerHTML = `<span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span> <span>AI Server ออนไลน์</span>`;
      } else {
        badge.className = 'hidden sm:inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[11px] font-medium bg-slate-100 text-slate-600 border border-slate-200';
        badge.innerHTML = `<span class="w-2 h-2 rounded-full bg-slate-400"></span> <span>โหมดสแตนด์อโลน (ออฟไลน์)</span>`;
      }
    }
  }

  // Inject UI Modals
  function injectModals() {
    if (document.getElementById('aiUploadModal')) return;

    const modalContainer = document.createElement('div');
    modalContainer.innerHTML = `
      <!-- Toast Container -->
      <div id="aiToastContainer" class="fixed bottom-5 right-5 z-50 flex flex-col gap-2 pointer-events-none"></div>

      <!-- Settings Modal -->
      <div id="aiSettingsModal" class="hidden fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
        <div class="bg-white rounded-2xl shadow-2xl max-w-md w-full border border-slate-100 overflow-hidden animate-in fade-in zoom-in-95 duration-150">
          <div class="px-6 py-4 bg-slate-900 text-white flex items-center justify-between">
            <div class="flex items-center gap-2">
              <span class="text-xl">⚙️</span>
              <h3 class="font-bold text-sm sm:text-base">ตั้งค่าระบบและ Google Gemini API</h3>
            </div>
            <button onclick="window.closeSettingsModal()" class="text-slate-400 hover:text-white text-lg leading-none">&times;</button>
          </div>
          <div class="p-6 space-y-4 text-xs sm:text-sm">
            <div>
              <label class="block font-semibold text-slate-700 mb-1">Google Gemini API Key</label>
              <div class="relative">
                <input type="password" id="inputGeminiApiKey" placeholder="AIzaSy... (วาง Gemini API Key ที่นี่)" class="w-full font-mono text-xs px-3 py-2.5 rounded-xl border border-slate-300 focus:ring-2 focus:ring-indigo-500 pr-10">
                <button type="button" onclick="window.toggleApiKeyVisibility()" class="absolute right-2.5 top-2.5 text-slate-400 hover:text-slate-600">👁️</button>
              </div>
              <div id="boxKeySavedStatus" class="hidden mt-2 p-2.5 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs flex items-center justify-between">
                <span class="flex items-center gap-1.5">
                  <span>🔑</span>
                  <span id="txtKeySavedMasked">มี API Key บันทึกไว้แล้ว</span>
                </span>
                <span class="text-[10px] bg-emerald-200 text-emerald-900 px-2 py-0.5 rounded-full font-semibold">พร้อมใช้งาน</span>
              </div>
              <p class="text-[11px] text-slate-500 mt-1.5">รับ API Key ได้ฟรีที่ <a href="https://aistudio.google.com/app/apikey" target="_blank" class="text-indigo-600 font-semibold hover:underline">Google AI Studio (คลิก)</a></p>
              <div id="testConnectionResult" class="hidden p-3 rounded-xl text-xs font-medium mt-2"></div>
            </div>
            <div>
              <label class="block font-semibold text-slate-700 mb-1">โมเดล AI Vision</label>
              <select id="selectGeminiModel" class="w-full text-xs px-3 py-2.5 rounded-xl border border-slate-300 focus:ring-2 focus:ring-indigo-500">
                <option value="gemini-3.5-flash-lite">Gemini 3.5 Flash-Lite (แนะนำ: รวดเร็ว แม่นยำ อ่านลายมือไทยดีเยี่ยม)</option>
                <option value="gemini-3.8-flash">Gemini 3.8 Flash (โมเดลเรือธง ความสามารถสูง)</option>
                <option value="gemini-flash-latest">Gemini Flash Latest (อัปเดตอัตโนมัติ)</option>
              </select>
            </div>
            <div id="settingsServerStatus" class="p-3 rounded-xl bg-slate-50 border border-slate-200 text-xs space-y-1">
              <div class="flex items-center justify-between">
                <span class="font-semibold text-slate-600">สถานะ Local Server:</span>
                <span id="txtServerStatus" class="font-bold text-slate-500">กำลังตรวจสอบ...</span>
              </div>
              <div class="text-[11px] text-slate-500">
                บันทึกค่าไว้ใน <code class="bg-white px-1 py-0.5 rounded border border-slate-200">config.json</code> ในโฟลเดอร์ร้าน
              </div>
            </div>
          </div>
          <div class="px-6 py-3.5 bg-slate-50 border-t border-slate-200 flex items-center justify-between">
            <button onclick="window.testGeminiConnection()" class="px-3.5 py-2 rounded-xl text-xs font-semibold border border-slate-300 hover:bg-slate-100 text-slate-700 transition">
              🔍 ทดสอบเชื่อมต่อ
            </button>
            <div class="flex items-center gap-2">
              <button onclick="window.closeSettingsModal()" class="px-4 py-2 rounded-xl text-xs font-semibold text-slate-600 hover:bg-slate-200 transition">ยกเลิก</button>
              <button onclick="window.saveSettings()" class="px-4 py-2 rounded-xl text-xs font-semibold bg-indigo-600 hover:bg-indigo-700 text-white shadow-sm transition">💾 บันทึกการตั้งค่า</button>
            </div>
          </div>
        </div>
      </div>

      <!-- Upload & AI Vision Modal -->
      <div id="aiUploadModal" class="hidden fixed inset-0 z-50 bg-slate-900/70 backdrop-blur-sm flex items-center justify-center p-2 sm:p-4">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-6xl max-h-[94vh] flex flex-col border border-slate-100 overflow-hidden animate-in fade-in zoom-in-95 duration-150">
          
          <!-- Modal Header -->
          <div class="px-5 py-3.5 bg-gradient-to-r from-slate-900 via-indigo-950 to-slate-900 text-white flex items-center justify-between shrink-0">
            <div class="flex items-center gap-2.5">
              <div class="w-8 h-8 rounded-lg bg-indigo-500/30 border border-indigo-400/30 flex items-center justify-center text-lg shadow-inner">
                ✨
              </div>
              <div>
                <h3 class="font-bold text-sm sm:text-base leading-tight">ระบบ AI Vision อ่านสลิปและใบสรุปยอด</h3>
                <p class="text-[11px] text-indigo-200">อัปโหลดรูปภาพใบสรุปประจำวัน หรือสลิปรายจ่าย แปลงข้อมูลลง Dashboard อัตโนมัติ</p>
              </div>
            </div>
            <button onclick="window.closeUploadModal()" class="w-8 h-8 rounded-lg hover:bg-white/10 text-slate-300 hover:text-white flex items-center justify-center text-xl leading-none transition">&times;</button>
          </div>

          <!-- Modal Body Content -->
          <div class="flex-1 overflow-y-auto p-4 sm:p-5 space-y-4">

            <!-- Step 1: Dropzone (Hidden when reviewing) -->
            <div id="aiDropzoneContainer" class="border-2 border-dashed border-indigo-200 hover:border-indigo-400 rounded-2xl p-6 sm:p-8 bg-indigo-50/30 hover:bg-indigo-50/60 transition text-center cursor-pointer group">
              <input type="file" id="aiFileInput" multiple accept="image/*" class="hidden">
              <div class="w-14 h-14 mx-auto rounded-2xl bg-indigo-100 text-indigo-600 flex items-center justify-center text-2xl mb-3 group-hover:scale-110 transition shadow-sm">
                📤
              </div>
              <h4 class="font-bold text-slate-800 text-sm sm:text-base mb-1">คลิกเลือกรูปภาพ หรือ ลากไฟล์รูปมาวางที่นี่</h4>
              <p class="text-xs text-slate-500 mb-3">รองรับทั้งรูปเดี่ยว และเลือกหลายรูปพร้อมกัน (JPG, PNG, WEBP) เช่น ใบสรุป 4 สาขา หรือบิลค่าใช้จ่าย</p>
              <div class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-white border border-slate-200 text-slate-600 text-[11px] shadow-xs">
                <span>⚡ AI จะอ่านสาขา วันที่ ยอดขายสด/โอน และแจกแจงค่าใช้จ่ายให้อัตโนมัติ</span>
              </div>
            </div>

            <!-- Batch Progress Bar & Tabs -->
            <div id="aiBatchQueueSection" class="hidden space-y-2">
              <div class="flex items-center justify-between text-xs">
                <span class="font-semibold text-slate-700 flex items-center gap-1.5">
                  <span>📑 รายการรูปภาพในชุด (<span id="txtBatchProgress">0/0</span>)</span>
                </span>
                <button onclick="window.addMoreImages()" class="text-indigo-600 hover:text-indigo-800 text-xs font-semibold">+ เพิ่มรูปภาพ</button>
              </div>
              <!-- Thumbnails row -->
              <div id="aiThumbnailsRow" class="flex gap-2 overflow-x-auto pb-1 no-scrollbar"></div>
            </div>

            <!-- Step 2: Side-by-side Review Panel -->
            <div id="aiReviewSection" class="hidden grid grid-cols-1 lg:grid-cols-12 gap-5">
              
              <!-- LEFT: Image Preview & Zoom Controls -->
              <div class="lg:col-span-6 flex flex-col bg-slate-900 rounded-2xl overflow-hidden border border-slate-800 shadow-md">
                <!-- Image Header Bar -->
                <div class="px-4 py-2.5 bg-slate-950/80 border-b border-slate-800 flex items-center justify-between text-white text-xs">
                  <div class="flex items-center gap-2 truncate max-w-[200px] sm:max-w-[300px]">
                    <span id="lblImageFileName" class="truncate font-mono text-[11px] text-slate-300">image.jpg</span>
                  </div>
                  <div class="flex items-center gap-1.5">
                    <button onclick="window.zoomImage(0.2)" class="w-7 h-7 rounded bg-slate-800 hover:bg-slate-700 text-white flex items-center justify-center font-bold" title="ซูมเข้า">+</button>
                    <button onclick="window.zoomImage(-0.2)" class="w-7 h-7 rounded bg-slate-800 hover:bg-slate-700 text-white flex items-center justify-center font-bold" title="ซูมออก">-</button>
                    <button onclick="window.rotateImage()" class="w-7 h-7 rounded bg-slate-800 hover:bg-slate-700 text-white flex items-center justify-center" title="หมุนรูป 90°">🔄</button>
                    <button onclick="window.resetZoom()" class="px-2 h-7 rounded bg-slate-800 hover:bg-slate-700 text-white text-[10px]" title="รีเซ็ตขนาด">100%</button>
                  </div>
                </div>
                <!-- Image Viewport -->
                <div class="relative flex-1 min-h-[360px] max-h-[560px] bg-slate-950 flex items-center justify-center overflow-hidden p-2">
                  <img id="aiPreviewImg" src="" alt="ภาพสแกน" class="max-w-full max-h-full object-contain transition-transform duration-100 ease-out select-none">
                  <div id="aiImageLoadingOverlay" class="hidden absolute inset-0 bg-slate-900/80 backdrop-blur-xs flex flex-col items-center justify-center text-white space-y-3">
                    <div class="w-10 h-10 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin"></div>
                    <span class="text-xs font-semibold animate-pulse">Gemini AI กำลังวิเคราะห์ข้อมูล...</span>
                  </div>
                </div>
              </div>

              <!-- RIGHT: Extracted Editable Form -->
              <div class="lg:col-span-6 flex flex-col bg-slate-50/70 rounded-2xl p-4 sm:p-5 border border-slate-200 shadow-sm space-y-4">
                
                <!-- Status & AI Tag -->
                <div class="flex flex-wrap items-center justify-between gap-2 pb-2 border-b border-slate-200">
                  <div class="flex items-center gap-2">
                    <span id="badgeDocType" class="px-2.5 py-0.5 rounded-full text-xs font-bold bg-indigo-100 text-indigo-800 border border-indigo-200">
                      📄 ใบสรุปยอดประจำวัน
                    </span>
                    <span id="badgeConfidence" class="text-[11px] text-emerald-700 font-medium">✅ วิเคราะห์สำเร็จ</span>
                  </div>
                  <button onclick="window.reAnalyzeCurrentImage()" class="text-xs text-indigo-600 hover:text-indigo-800 font-semibold flex items-center gap-1">
                    <span>🔄</span> ให้ AI อ่านใหม่อีกครั้ง
                  </button>
                </div>

                <!-- Form Fields Grid -->
                <div class="grid grid-cols-2 sm:grid-cols-3 gap-3">
                  <!-- Branch -->
                  <div class="col-span-1">
                    <label class="block text-[11px] font-bold text-slate-700 mb-1">🏬 สาขา</label>
                    <select id="formBranchId" onchange="window.onFormBranchChange()" class="w-full text-xs font-semibold px-2.5 py-2 rounded-xl border border-slate-300 bg-white focus:ring-2 focus:ring-indigo-500">
                      <option value="1">🔵 สาขา 1</option>
                      <option value="2">🟠 สาขา 2</option>
                      <option value="3">🟢 สาขา 3</option>
                      <option value="4">🟣 สาขา 4</option>
                    </select>
                  </div>
                  <!-- Day / Date -->
                  <div class="col-span-1">
                    <label class="block text-[11px] font-bold text-slate-700 mb-1">📅 วันที่ประจำเดือน</label>
                    <input type="number" id="formDayNumber" min="1" max="31" class="w-full text-xs font-bold font-num px-2.5 py-2 rounded-xl border border-slate-300 bg-white focus:ring-2 focus:ring-indigo-500" placeholder="เช่น 2">
                  </div>
                  <!-- Date Text -->
                  <div class="col-span-2 sm:col-span-1">
                    <label class="block text-[11px] font-bold text-slate-700 mb-1">วันที่เต็ม</label>
                    <input type="text" id="formDateText" class="w-full text-xs font-num px-2.5 py-2 rounded-xl border border-slate-300 bg-white focus:ring-2 focus:ring-indigo-500" placeholder="YYYY-MM-DD">
                  </div>
                </div>

                <!-- Revenue Section -->
                <div class="p-3.5 bg-white rounded-xl border border-slate-200 space-y-2">
                  <div class="flex items-center justify-between">
                    <span class="text-xs font-bold text-slate-800 flex items-center gap-1">
                      <span>💰</span> ยอดขายรวม (รายรับ)
                    </span>
                    <div class="flex items-center gap-1.5">
                      <span class="text-[11px] text-slate-500">รวมรับ:</span>
                      <input type="number" id="formTotalSales" oninput="window.calcNetProfit()" class="w-28 text-right text-xs font-bold font-num px-2 py-1 rounded-lg border border-slate-300 bg-emerald-50/50 text-emerald-900 focus:ring-2 focus:ring-emerald-500">
                      <span class="text-xs font-bold text-slate-700">฿</span>
                    </div>
                  </div>
                  <div class="grid grid-cols-2 gap-2 pt-1 border-t border-slate-100 text-xs">
                    <div>
                      <label class="text-[10px] font-semibold text-slate-500 block">💵 ยอดเงินสด</label>
                      <input type="number" id="formCashSales" class="w-full text-xs font-num px-2 py-1 rounded border border-slate-200">
                    </div>
                    <div>
                      <label class="text-[10px] font-semibold text-slate-500 block">📱 ยอดเงินโอน</label>
                      <input type="number" id="formTransferSales" class="w-full text-xs font-num px-2 py-1 rounded border border-slate-200">
                    </div>
                  </div>
                </div>

                <!-- Expenses Section -->
                <div class="p-3.5 bg-white rounded-xl border border-slate-200 space-y-2.5">
                  <div class="flex items-center justify-between">
                    <span class="text-xs font-bold text-slate-800 flex items-center gap-1">
                      <span>💸</span> รายจ่ายหน้าร้านรวม
                    </span>
                    <div class="flex items-center gap-1.5">
                      <input type="number" id="formTotalExpenses" oninput="window.calcNetProfit()" class="w-28 text-right text-xs font-bold font-num px-2 py-1 rounded-lg border border-slate-300 bg-rose-50/50 text-rose-900 focus:ring-2 focus:ring-rose-500">
                      <span class="text-xs font-bold text-slate-700">฿</span>
                    </div>
                  </div>

                  <!-- Itemized Table -->
                  <div class="space-y-1">
                    <div class="flex items-center justify-between text-[11px] text-slate-500 font-semibold px-1">
                      <span>รายการค่าใช้จ่ายที่ AI สแกนพบ:</span>
                      <button onclick="window.addExpenseRow()" class="text-indigo-600 hover:text-indigo-800 font-bold">+ เพิ่มรายการ</button>
                    </div>
                    <div id="formExpenseItemsList" class="max-h-28 overflow-y-auto space-y-1.5 pr-1"></div>
                  </div>
                </div>

                <!-- Bottom Summary & Notes -->
                <div class="grid grid-cols-2 gap-2 text-xs">
                  <div class="p-2.5 bg-slate-100 rounded-xl">
                    <span class="text-[10px] text-slate-500 block">กำไร/ขาดทุนหน้าร้าน</span>
                    <span id="formNetProfitDisplay" class="font-bold text-sm font-num text-slate-800">฿0.00</span>
                  </div>
                  <div class="p-2.5 bg-slate-100 rounded-xl">
                    <span class="text-[10px] text-slate-500 block">ยอดส่งโอน / ส่งสด</span>
                    <input type="number" id="formRemittance" class="w-full text-xs font-num px-1.5 py-0.5 bg-white rounded border border-slate-300">
                  </div>
                </div>

                <div>
                  <label class="block text-[11px] font-bold text-slate-700 mb-1">📝 สรุปรายละเอียด/หมายเหตุ</label>
                  <textarea id="formSummaryNote" rows="2" class="w-full text-xs px-2.5 py-1.5 rounded-xl border border-slate-300 bg-white"></textarea>
                </div>

              </div>

            </div>

          </div>

          <!-- Modal Footer Actions -->
          <div class="px-5 py-3.5 bg-slate-50 border-t border-slate-200 flex flex-wrap items-center justify-between gap-3 shrink-0">
            <div class="flex items-center gap-2">
              <button id="btnPrevImage" onclick="window.stepBatchImage(-1)" class="px-3 py-1.5 rounded-xl border border-slate-300 bg-white hover:bg-slate-100 text-xs font-semibold text-slate-700 transition disabled:opacity-40">
                ◀ รูปก่อนหน้า
              </button>
              <button id="btnNextImage" onclick="window.stepBatchImage(1)" class="px-3 py-1.5 rounded-xl border border-slate-300 bg-white hover:bg-slate-100 text-xs font-semibold text-slate-700 transition disabled:opacity-40">
                รูปถัดไป ▶
              </button>
            </div>
            <div class="flex items-center gap-2.5">
              <button onclick="window.closeUploadModal()" class="px-4 py-2 rounded-xl text-xs font-semibold text-slate-600 hover:bg-slate-200 transition">
                ปิดหน้าต่าง
              </button>
              <button id="btnSaveAiEntry" onclick="window.saveCurrentAiEntry()" class="px-5 py-2 rounded-xl text-xs font-semibold bg-emerald-600 hover:bg-emerald-700 text-white shadow-sm transition flex items-center gap-1.5">
                <span>💾</span>
                <span>ยืนยันและบันทึกลงแดชบอร์ด</span>
              </button>
            </div>
          </div>

        </div>
      </div>
    `;

    document.body.appendChild(modalContainer);

    // Setup Drag and Drop events
    setupDropzone();
  }

  function setupDropzone() {
    const dropzone = document.getElementById('aiDropzoneContainer');
    const fileInput = document.getElementById('aiFileInput');
    if (!dropzone || !fileInput) return;

    dropzone.addEventListener('click', () => fileInput.click());

    fileInput.addEventListener('change', (e) => {
      if (e.target.files && e.target.files.length > 0) {
        handleSelectedFiles(Array.from(e.target.files));
      }
    });

    ['dragenter', 'dragover'].forEach(eventName => {
      dropzone.addEventListener(eventName, (e) => {
        e.preventDefault();
        e.stopPropagation();
        dropzone.classList.add('border-indigo-600', 'bg-indigo-100/50');
      }, false);
    });

    ['dragleave', 'drop'].forEach(eventName => {
      dropzone.addEventListener(eventName, (e) => {
        e.preventDefault();
        e.stopPropagation();
        dropzone.classList.remove('border-indigo-600', 'bg-indigo-100/50');
      }, false);
    });

    dropzone.addEventListener('drop', (e) => {
      const dt = e.dataTransfer;
      const files = dt.files;
      if (files && files.length > 0) {
        handleSelectedFiles(Array.from(files));
      }
    });
  }

  // Handle selected files
  async function handleSelectedFiles(files) {
    const imageFiles = files.filter(f => f.type.startsWith('image/'));
    if (imageFiles.length === 0) {
      showToast('กรุณาเลือกไฟล์รูปภาพเท่านั้น (JPG, PNG, WEBP)', 'error');
      return;
    }

    // Append to queue
    const startIndex = uploadQueue.length;
    for (const file of imageFiles) {
      const base64 = await readFileAsBase64(file);
      uploadQueue.push({
        file,
        base64,
        mimeType: file.type || 'image/jpeg',
        status: 'pending', // pending, analyzing, success, error, saved
        result: null,
        error: null
      });
    }

    // Switch view to review
    document.getElementById('aiDropzoneContainer').classList.add('hidden');
    document.getElementById('aiBatchQueueSection').classList.remove('hidden');
    document.getElementById('aiReviewSection').classList.remove('hidden');

    renderThumbnails();
    setActiveImage(startIndex);
    startBatchProcessing();
  }

  function readFileAsBase64(file) {
    return new Promise((resolve) => {
      const reader = new FileReader();
      reader.onload = (e) => resolve(e.target.result);
      reader.readAsDataURL(file);
    });
  }

  // Batch process images sequentially
  async function startBatchProcessing() {
    for (let i = 0; i < uploadQueue.length; i++) {
      if (uploadQueue[i].status === 'pending') {
        uploadQueue[i].status = 'analyzing';
        renderThumbnails();
        if (i === activeIndex) {
          showImageLoading(true);
        }
        await analyzeQueueItem(i);
        renderThumbnails();
        if (i === activeIndex) {
          showImageLoading(false);
          populateFormWithResult(uploadQueue[i].result);
        }
      }
    }
  }

  // Analyze single image via Backend API or Client-side Gemini
  async function analyzeQueueItem(index) {
    const item = uploadQueue[index];
    try {
      if (config.serverAvailable) {
        // Send to PowerShell Server backend
        const res = await fetch('/api/analyze-image', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            image: item.base64,
            mimeType: item.mimeType
          })
        });
        const resData = await res.json();
        if (!res.ok || !resData.success) {
          throw new Error(resData.error || 'Server error');
        }
        item.status = 'success';
        item.result = resData.data;
      } else {
        // Client-side Direct Call to Gemini
        const apiKey = config.apiKey || localStorage.getItem('gemini_api_key');
        if (!apiKey) {
          throw new Error('ยังไม่ได้ตั้งค่า Gemini API Key กรุณากดปุ่ม ⚙️ เพื่อใส่ Key ก่อนใช้งาน');
        }
        const model = config.model || 'gemini-3.5-flash-lite';
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

        let cleanBase64 = item.base64;
        if (cleanBase64.includes(',')) {
          cleanBase64 = cleanBase64.split(',')[1];
        }

        const promptText = `คุณคือผู้เชี่ยวชาญ AI ในการอ่านเอกสารบัญชีภาษาไทย ลายมือ สลิปโอนเงินธนาคาร และกระดาษจดสรุปยอดประจำวันของร้านลูกชิ้น (มี 4 สาขา: สาขา 1, สาขา 2, สาขา 3, สาขา 4)

จงวิเคราะห์ภาพและสกัดข้อมูลออกมาเป็น JSON ตาม schema ดังนี้:
{
  "document_type": "daily_summary" หรือ "expense_receipt" หรือ "transfer_slip",
  "branch_id": 1 หรือ 2 หรือ 3 หรือ 4 (ถ้ามีระบุสาขา ให้ตอบตามนั้น ถ้าไม่ชัดเจนให้คาดเดาจากบริบทหรือตอบ 1),
  "date": "YYYY-MM-DD",
  "day_number": เลขวันที่ของเดือน (จำนวนเต็ม 1-31),
  "total_sales": ยอดขายรวม (บาท),
  "cash_sales": ยอดเงินสด (บาท),
  "transfer_sales": ยอดเงินโอน (บาท),
  "total_expenses": ยอดรายจ่ายรวมหน้าร้าน (บาท),
  "expenses": [ { "item": "ชื่อรายการ", "amount": ตัวเลข, "category": "หมวดหมู่" } ],
  "rent": ค่าเช่า (ถ้ามี),
  "net_profit": กำไรหน้าร้าน,
  "remittance": เงินส่งโอน/ส่งสด,
  "summary_note": "สรุปรายละเอียดสั้นๆ เช่น สด ฿764, โอน ฿270, รวมรับ ฿1,034...",
  "confidence_notes": "ข้อสังเกตเพิ่มเติม"
}
ตอบเฉพาะ JSON ล้วนเท่านั้น`;

        const geminiRes = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{
              role: 'user',
              parts: [
                { text: promptText },
                { inline_data: { mime_type: item.mimeType, data: cleanBase64 } }
              ]
            }],
            generationConfig: {
              temperature: 0.1,
              response_mime_type: 'application/json'
            }
          })
        });

        if (!geminiRes.ok) {
          const errBody = await geminiRes.text();
          throw new Error(`Gemini API Error: ${errBody}`);
        }
        const data = await geminiRes.json();
        let rawText = data.candidates[0].content.parts[0].text.trim();
        if (rawText.startsWith('```json')) rawText = rawText.substring(7);
        if (rawText.startsWith('```')) rawText = rawText.substring(3);
        if (rawText.endsWith('```')) rawText = rawText.substring(0, rawText.length - 3);
        item.status = 'success';
        item.result = JSON.parse(rawText.trim());
      }
    } catch (err) {
      item.status = 'error';
      item.error = err.message;
      showToast(err.message, 'error');
    }
  }

  // Render Thumbnails row
  function renderThumbnails() {
    const row = document.getElementById('aiThumbnailsRow');
    const progressTxt = document.getElementById('txtBatchProgress');
    if (!row) return;

    const completed = uploadQueue.filter(q => q.status === 'success' || q.status === 'saved').length;
    if (progressTxt) progressTxt.textContent = `${completed}/${uploadQueue.length} ใบ`;

    row.innerHTML = uploadQueue.map((item, idx) => {
      const isActive = idx === activeIndex;
      let badge = '';
      if (item.status === 'analyzing') badge = '<span class="absolute top-1 right-1 w-2.5 h-2.5 rounded-full bg-amber-500 animate-ping"></span>';
      else if (item.status === 'success') badge = '<span class="absolute top-1 right-1 text-[10px]">✅</span>';
      else if (item.status === 'saved') badge = '<span class="absolute top-1 right-1 text-[10px]">💾</span>';
      else if (item.status === 'error') badge = '<span class="absolute top-1 right-1 text-[10px]">❌</span>';

      return `
        <button onclick="window.setActiveImage(${idx})" class="relative shrink-0 w-16 h-16 rounded-xl overflow-hidden border-2 transition ${isActive ? 'border-indigo-600 ring-2 ring-indigo-200' : 'border-slate-200 opacity-70 hover:opacity-100'}">
          <img src="${item.base64}" class="w-full h-full object-cover">
          ${badge}
          <div class="absolute bottom-0 inset-x-0 bg-slate-900/70 text-[9px] text-white text-center py-0.5 truncate px-1">
            #${idx + 1}
          </div>
        </button>
      `;
    }).join('');
  }

  function setActiveImage(index) {
    if (index < 0 || index >= uploadQueue.length) return;
    activeIndex = index;
    zoomLevel = 1;
    rotation = 0;

    const item = uploadQueue[activeIndex];
    const previewImg = document.getElementById('aiPreviewImg');
    const lblFileName = document.getElementById('lblImageFileName');
    if (previewImg) {
      previewImg.src = item.base64;
      previewImg.style.transform = `scale(1) rotate(0deg)`;
    }
    if (lblFileName) {
      lblFileName.textContent = `[#${activeIndex + 1}/${uploadQueue.length}] ${item.file.name}`;
    }

    renderThumbnails();

    // Update prev/next buttons
    const btnPrev = document.getElementById('btnPrevImage');
    const btnNext = document.getElementById('btnNextImage');
    if (btnPrev) btnPrev.disabled = (activeIndex === 0);
    if (btnNext) btnNext.disabled = (activeIndex === uploadQueue.length - 1);

    if (item.status === 'analyzing') {
      showImageLoading(true);
    } else {
      showImageLoading(false);
      if (item.result) {
        populateFormWithResult(item.result);
      }
    }
  }

  function showImageLoading(isLoading) {
    const overlay = document.getElementById('aiImageLoadingOverlay');
    if (overlay) {
      overlay.classList.toggle('hidden', !isLoading);
    }
  }

  // Populate form with AI result
  function populateFormWithResult(result) {
    if (!result) return;

    // Document type badge
    const badgeDocType = document.getElementById('badgeDocType');
    if (badgeDocType) {
      if (result.document_type === 'expense_receipt') {
        badgeDocType.textContent = '🧾 ใบเสร็จ/บิลค่าใช้จ่าย';
        badgeDocType.className = 'px-2.5 py-0.5 rounded-full text-xs font-bold bg-amber-100 text-amber-800 border border-amber-200';
      } else if (result.document_type === 'transfer_slip') {
        badgeDocType.textContent = '📱 สลิปโอนเงิน';
        badgeDocType.className = 'px-2.5 py-0.5 rounded-full text-xs font-bold bg-blue-100 text-blue-800 border border-blue-200';
      } else {
        badgeDocType.textContent = '📄 ใบสรุปยอดประจำวัน';
        badgeDocType.className = 'px-2.5 py-0.5 rounded-full text-xs font-bold bg-indigo-100 text-indigo-800 border border-indigo-200';
      }
    }

    // Branch
    const branchSelect = document.getElementById('formBranchId');
    if (branchSelect && result.branch_id) {
      branchSelect.value = String(result.branch_id);
    }

    // Day & Date
    const dayInput = document.getElementById('formDayNumber');
    if (dayInput) {
      dayInput.value = result.day_number || (result.date ? parseInt(result.date.split('-')[2], 10) : 2);
    }

    const dateInput = document.getElementById('formDateText');
    if (dateInput) {
      dateInput.value = result.date || new Date().toISOString().split('T')[0];
    }

    // Sales
    document.getElementById('formTotalSales').value = result.total_sales || 0;
    document.getElementById('formCashSales').value = result.cash_sales || 0;
    document.getElementById('formTransferSales').value = result.transfer_sales || 0;

    // Expenses
    document.getElementById('formTotalExpenses').value = result.total_expenses || 0;

    // Render expense items
    renderExpenseItems(result.expenses || []);

    // Profit & Remittance & Note
    document.getElementById('formRemittance').value = result.remittance || 0;
    document.getElementById('formSummaryNote').value = result.summary_note || '';

    calcNetProfit();
  }

  function renderExpenseItems(items) {
    const container = document.getElementById('formExpenseItemsList');
    if (!container) return;

    if (!items || items.length === 0) {
      container.innerHTML = '<div class="text-[11px] text-slate-400 italic">ไม่มีรายการย่อย</div>';
      return;
    }

    container.innerHTML = items.map((item, idx) => `
      <div class="flex items-center gap-1.5 bg-slate-50 p-1 rounded border border-slate-200 text-xs">
        <input type="text" value="${item.item || ''}" class="flex-1 px-1.5 py-0.5 bg-white rounded border border-slate-200 text-xs" placeholder="ชื่อรายการ">
        <input type="number" value="${item.amount || 0}" oninput="window.calcExpensesFromItems()" class="w-20 text-right px-1.5 py-0.5 bg-white rounded border border-slate-200 text-xs font-num font-semibold text-rose-700">
        <span class="text-[10px] text-slate-500">฿</span>
        <button onclick="this.parentElement.remove(); window.calcExpensesFromItems();" class="text-rose-500 hover:text-rose-700 text-xs px-1 font-bold">&times;</button>
      </div>
    `).join('');
  }

  function addExpenseRow() {
    const container = document.getElementById('formExpenseItemsList');
    if (!container) return;
    const div = document.createElement('div');
    div.className = 'flex items-center gap-1.5 bg-slate-50 p-1 rounded border border-slate-200 text-xs';
    div.innerHTML = `
      <input type="text" value="" class="flex-1 px-1.5 py-0.5 bg-white rounded border border-slate-200 text-xs" placeholder="ชื่อรายการ (เช่น วัตถุดิบ)">
      <input type="number" value="0" oninput="window.calcExpensesFromItems()" class="w-20 text-right px-1.5 py-0.5 bg-white rounded border border-slate-200 text-xs font-num font-semibold text-rose-700">
      <span class="text-[10px] text-slate-500">฿</span>
      <button onclick="this.parentElement.remove(); window.calcExpensesFromItems();" class="text-rose-500 hover:text-rose-700 text-xs px-1 font-bold">&times;</button>
    `;
    container.appendChild(div);
  }

  function calcExpensesFromItems() {
    const container = document.getElementById('formExpenseItemsList');
    if (!container) return;
    const rows = container.querySelectorAll('div');
    let total = 0;
    rows.forEach(row => {
      const inputs = row.querySelectorAll('input');
      if (inputs.length >= 2) {
        total += parseFloat(inputs[1].value) || 0;
      }
    });
    if (total > 0) {
      document.getElementById('formTotalExpenses').value = total;
      calcNetProfit();
    }
  }

  function calcNetProfit() {
    const rev = parseFloat(document.getElementById('formTotalSales').value) || 0;
    const exp = parseFloat(document.getElementById('formTotalExpenses').value) || 0;
    const net = rev - exp;
    const disp = document.getElementById('formNetProfitDisplay');
    if (disp) {
      disp.textContent = (net >= 0 ? '+' : '') + '฿' + net.toLocaleString('th-TH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
      disp.className = `font-bold text-sm font-num ${net >= 0 ? 'text-emerald-600' : 'text-rose-600'}`;
    }
  }

  // Save current entry
  async function saveCurrentAiEntry() {
    if (uploadQueue.length === 0) return;
    const item = uploadQueue[activeIndex];

    const branch = parseInt(document.getElementById('formBranchId').value, 10);
    const day = parseInt(document.getElementById('formDayNumber').value, 10);
    const totalSales = parseFloat(document.getElementById('formTotalSales').value) || 0;
    const cash = parseFloat(document.getElementById('formCashSales').value) || 0;
    const transfer = parseFloat(document.getElementById('formTransferSales').value) || 0;
    const totalExpenses = parseFloat(document.getElementById('formTotalExpenses').value) || 0;
    const remittance = parseFloat(document.getElementById('formRemittance').value) || 0;
    const note = document.getElementById('formSummaryNote').value;

    const btnSave = document.getElementById('btnSaveAiEntry');
    btnSave.disabled = true;
    btnSave.innerHTML = `<span class="animate-spin mr-1.5">⏳</span> กำลังบันทึก...`;

    try {
      if (config.serverAvailable) {
        // Send to backend
        const res = await fetch('/api/save-entry', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            branch,
            day,
            totalSales,
            cash,
            transfer,
            expenses: totalExpenses,
            remittance,
            note,
            imageData: item.base64
          })
        });
        const resData = await res.json();
        if (!res.ok || !resData.success) {
          throw new Error(resData.error || 'บันทึกไม่สำเร็จ');
        }
      }

      // Update in-memory and local storage data for immediate UI refresh
      updateLocalDataAndDashboard(branch, day, totalSales, totalExpenses, note);

      item.status = 'saved';
      renderThumbnails();
      showToast(`บันทึกยอด สาขา ${branch} วันที่ ${day} เรียบร้อยแล้ว!`, 'success');

      // Auto step to next image if available
      if (activeIndex < uploadQueue.length - 1) {
        setTimeout(() => setActiveImage(activeIndex + 1), 500);
      }

    } catch (err) {
      showToast('เกิดข้อผิดพลาดในการบันทึก: ' + err.message, 'error');
    } finally {
      btnSave.disabled = false;
      btnSave.innerHTML = `<span>💾</span> <span>ยืนยันและบันทึกลงแดชบอร์ด</span>`;
    }
  }

  // Update in-memory dailyData and trigger Dashboard redraw
  function updateLocalDataAndDashboard(branch, day, sales, expenses, note) {
    if (typeof dailyData === 'undefined') return;

    let row = dailyData.find(d => d.day === day);
    if (!row) {
      row = { day, r1: 0, r2: 0, r3: 0, r4: 0, e1: 0, e2: 0, e3: 0, e4: 0 };
      dailyData.push(row);
      dailyData.sort((a, b) => a.day - b.day);
    }

    row['r' + branch] = sales;
    row['e' + branch] = expenses;

    // Recalculate branchMeta
    if (typeof branchMeta !== 'undefined') {
      const sumR1 = dailyData.reduce((s, d) => s + d.r1, 0);
      const sumR2 = dailyData.reduce((s, d) => s + d.r2, 0);
      const sumR3 = dailyData.reduce((s, d) => s + d.r3, 0);
      const sumR4 = dailyData.reduce((s, d) => s + d.r4, 0);
      branchMeta.branch1.rev = sumR1;
      branchMeta.branch2.rev = sumR2;
      branchMeta.branch3.rev = sumR3;
      branchMeta.branch4.rev = sumR4;
      branchMeta.all.rev = sumR1 + sumR2 + sumR3 + sumR4;
    }

    // Update branch notes
    if (typeof branchNotes !== 'undefined' && note) {
      const bKey = 'branch' + branch;
      if (!branchNotes[bKey]) branchNotes[bKey] = {};
      branchNotes[bKey][day] = note;
    }

    // Save to LocalStorage
    try {
      localStorage.setItem('financial_dashboard_nov69_data', JSON.stringify({ dailyData }));
    } catch (e) {
      console.warn(e);
    }

    // Trigger dashboard updates
    if (typeof updateDashboard === 'function') updateDashboard();
    if (typeof renderTrendChart === 'function') renderTrendChart();
    if (typeof renderDonut === 'function') renderDonut();
    if (typeof renderTable === 'function') renderTable();
  }

  // Zoom and Rotate Controls
  function zoomImage(delta) {
    zoomLevel = Math.max(0.5, Math.min(3, zoomLevel + delta));
    applyImageTransform();
  }

  function rotateImage() {
    rotation = (rotation + 90) % 360;
    applyImageTransform();
  }

  function resetZoom() {
    zoomLevel = 1;
    rotation = 0;
    applyImageTransform();
  }

  function applyImageTransform() {
    const img = document.getElementById('aiPreviewImg');
    if (img) {
      img.style.transform = `scale(${zoomLevel}) rotate(${rotation}deg)`;
    }
  }

  // Toast Notification
  function showToast(message, type = 'info') {
    const container = document.getElementById('aiToastContainer');
    if (!container) return;

    const toast = document.createElement('div');
    const bg = type === 'error' ? 'bg-rose-600' : type === 'success' ? 'bg-emerald-600' : 'bg-slate-800';
    toast.className = `${bg} text-white text-xs px-4 py-2.5 rounded-xl shadow-xl flex items-center gap-2 pointer-events-auto animate-in slide-in-from-right duration-200`;
    toast.innerHTML = `
      <span>${type === 'error' ? '⚠️' : type === 'success' ? '✅' : 'ℹ️'}</span>
      <span>${message}</span>
    `;

    container.appendChild(toast);
    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transition = 'opacity 0.3s ease';
      setTimeout(() => toast.remove(), 300);
    }, 4000);
  }

  // Export functions to window
  window.openUploadModal = () => {
    document.getElementById('aiUploadModal').classList.remove('hidden');
  };

  window.closeUploadModal = () => {
    document.getElementById('aiUploadModal').classList.add('hidden');
  };

  window.openSettingsModal = async () => {
    document.getElementById('aiSettingsModal').classList.remove('hidden');
    const inputKey = document.getElementById('inputGeminiApiKey');
    const selectModel = document.getElementById('selectGeminiModel');
    const txtStatus = document.getElementById('txtServerStatus');
    const boxKeySaved = document.getElementById('boxKeySavedStatus');
    const txtKeySavedMasked = document.getElementById('txtKeySavedMasked');
    const resultBox = document.getElementById('testConnectionResult');
    if (resultBox) resultBox.classList.add('hidden');

    if (config.hasApiKey) {
      if (boxKeySaved) {
        boxKeySaved.classList.remove('hidden');
        if (txtKeySavedMasked) {
          txtKeySavedMasked.textContent = `มี API Key บันทึกในระบบแล้ว (${config.maskedKey || '••••••••'})`;
        }
      }
      if (inputKey) {
        inputKey.placeholder = '•••••••••••••••• (พิมพ์ใหม่หากต้องการเปลี่ยน)';
        inputKey.value = '';
      }
    } else {
      if (boxKeySaved) boxKeySaved.classList.add('hidden');
      if (inputKey) {
        inputKey.placeholder = 'AIzaSy... (วาง Gemini API Key ที่นี่)';
        inputKey.value = config.apiKey || '';
      }
    }

    if (selectModel) selectModel.value = config.model || 'gemini-3.5-flash-lite';
    if (txtStatus) {
      txtStatus.textContent = config.serverAvailable ? '✅ พร้อมใช้งาน (พอร์ต 8080)' : '⚠️ โหมดออฟไลน์ (Standalone)';
      txtStatus.className = `font-bold ${config.serverAvailable ? 'text-emerald-600' : 'text-amber-600'}`;
    }
  };

  window.closeSettingsModal = () => {
    document.getElementById('aiSettingsModal').classList.add('hidden');
  };

  window.toggleApiKeyVisibility = () => {
    const input = document.getElementById('inputGeminiApiKey');
    if (input) input.type = input.type === 'password' ? 'text' : 'password';
  };

  window.saveSettings = async () => {
    const inputEl = document.getElementById('inputGeminiApiKey');
    const enteredKey = inputEl ? inputEl.value.trim() : '';
    const model = document.getElementById('selectGeminiModel').value;

    const hasNewKey = enteredKey && !enteredKey.includes('...') && !enteredKey.includes('***');
    if (hasNewKey) {
      config.apiKey = enteredKey;
      config.hasApiKey = true;
    }

    if (config.serverAvailable) {
      try {
        const payload = { model };
        if (hasNewKey) { payload.apiKey = enteredKey; }
        const res = await fetch('/api/config', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        if (res.ok) {
          showToast('บันทึกการตั้งค่าเรียบร้อยแล้ว', 'success');
          await checkServerAndConfig();
        }
      } catch (e) {
        showToast('ไม่สามารถบันทึกลงเซิร์ฟเวอร์ได้: ' + e.message, 'error');
      }
    }

    if (hasNewKey) {
      localStorage.setItem('gemini_api_key', enteredKey);
    }
    localStorage.setItem('gemini_model', model);
    config.model = model;

    window.closeSettingsModal();
  };

  window.testGeminiConnection = async () => {
    const inputEl = document.getElementById('inputGeminiApiKey');
    const enteredKey = inputEl ? inputEl.value.trim() : '';
    const model = document.getElementById('selectGeminiModel').value;
    const resultBox = document.getElementById('testConnectionResult');

    const hasKey = enteredKey || config.hasApiKey || config.apiKey;
    if (!hasKey) {
      if (resultBox) {
        resultBox.className = 'p-3 rounded-xl bg-amber-50 border border-amber-200 text-amber-800 text-xs';
        resultBox.innerHTML = '⚠️ กรุณาวาง Gemini API Key ก่อนกดทดสอบ (ขึ้นต้นด้วย AIzaSy...)';
        resultBox.classList.remove('hidden');
      }
      return;
    }

    if (resultBox) {
      resultBox.className = 'p-3 rounded-xl bg-blue-50 border border-blue-200 text-blue-800 text-xs flex items-center gap-2';
      resultBox.innerHTML = '<span class="animate-spin text-base">⏳</span> <span>กำลังทดสอบเชื่อมต่อ Google Gemini API...</span>';
      resultBox.classList.remove('hidden');
    }

    try {
      if (config.serverAvailable) {
        const res = await fetch('/api/test-key', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ apiKey: enteredKey, model })
        });
        const data = await res.json();
        if (res.ok && data.success) {
          resultBox.className = 'p-3 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs';
          resultBox.innerHTML = `🎉 <strong>เชื่อมต่อสำเร็จ!</strong> ${data.message}`;
          showToast('เชื่อมต่อสำเร็จพร้อมใช้งาน!', 'success');
        } else {
          resultBox.className = 'p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 text-xs space-y-1';
          resultBox.innerHTML = `<div>❌ <strong>เชื่อมต่อไม่สำเร็จ:</strong> ${data.error || 'เกิดข้อผิดพลาด'}</div>${data.rawError ? `<div class="text-[10px] text-rose-600 font-mono break-all mt-1">${data.rawError}</div>` : ''}`;
          showToast('เกิดข้อผิดพลาดในการเชื่อมต่อ', 'error');
        }
      } else {
        const keyToUse = enteredKey || config.apiKey;
        const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${keyToUse}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [{ text: 'สวัสดี' }] }]
          })
        });

        if (res.ok) {
          resultBox.className = 'p-3 rounded-xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs';
          resultBox.innerHTML = `🎉 <strong>เชื่อมต่อสำเร็จ!</strong> Google Gemini (${model}) พร้อมใช้งาน`;
          showToast('เชื่อมต่อสำเร็จพร้อมใช้งาน!', 'success');
        } else {
          const errText = await res.text();
          let msg = errText;
          try {
            const errObj = JSON.parse(errText);
            if (errObj.error && errObj.error.message) msg = errObj.error.message;
          } catch(e) {}

          let friendly = msg;
          if (msg.includes('API_KEY_INVALID') || msg.includes('API key not valid')) {
            friendly = 'API Key ไม่ถูกต้อง กรุณาคัดลอก Key ให้ครบถ้วนจาก Google AI Studio (ขึ้นต้นด้วย AIzaSy...)';
          }

          resultBox.className = 'p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 text-xs space-y-1';
          resultBox.innerHTML = `<div>❌ <strong>เชื่อมต่อไม่สำเร็จ:</strong> ${friendly}</div><div class="text-[10px] text-rose-600 font-mono break-all mt-1">${msg}</div>`;
          showToast('เกิดข้อผิดพลาดในการเชื่อมต่อ', 'error');
        }
      }
    } catch (e) {
      if (resultBox) {
        resultBox.className = 'p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 text-xs';
        resultBox.innerHTML = `❌ <strong>เกิดข้อผิดพลาด:</strong> ${e.message} (กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต)`;
      }
      showToast('เกิดข้อผิดพลาดในการเชื่อมต่อ: ' + e.message, 'error');
    }
  };

  window.addMoreImages = () => {
    document.getElementById('aiFileInput').click();
  };

  window.stepBatchImage = (delta) => {
    setActiveImage(activeIndex + delta);
  };

  window.setActiveImage = setActiveImage;
  window.zoomImage = zoomImage;
  window.rotateImage = rotateImage;
  window.resetZoom = resetZoom;
  window.addExpenseRow = addExpenseRow;
  window.calcExpensesFromItems = calcExpensesFromItems;
  window.calcNetProfit = calcNetProfit;
  window.saveCurrentAiEntry = saveCurrentAiEntry;
  window.reAnalyzeCurrentImage = () => {
    if (uploadQueue[activeIndex]) {
      uploadQueue[activeIndex].status = 'pending';
      uploadQueue[activeIndex].result = null;
      startBatchProcessing();
    }
  };

})();

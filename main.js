// ====== main.js ======

const VPS_API_URL = 'https://scripts.onyx-scripts.com/api/scripts'; 
let isAdminLoggedIn = false;
let brandClickCount = 0;
let brandClickTimer;

window.onload = function() {
    checkCooldown();
    iniciarContadorUsuarios(); 
};

// AL PONER "window." PROTEGEMOS LA FUNCIÓN DEL OFUSCADOR PARA QUE EL HTML LA ENCUENTRE
window.cambiarPagina = function(pageId) {
    const secciones = document.querySelectorAll('.page-section');
    secciones.forEach(sec => sec.classList.remove('active'));
    document.getElementById('page-' + pageId).classList.add('active');

    const links = document.querySelectorAll('.nav-links .nav-link');
    links.forEach(l => l.classList.remove('active'));
    
    let linkActive = document.querySelector(`.nav-links a[onclick="cambiarPagina('${pageId}')"]`);
    if(linkActive) linkActive.classList.add('active');

    window.scrollTo({ top: 0, behavior: 'smooth' });
};

// Función interna (No necesita window)
function mostrarAlerta(msg) {
    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay';
    const box = document.createElement('div');
    box.className = 'modal-box';
    box.innerHTML = `
        <p style="color:#fff; margin-bottom:25px; font-weight:600; font-family: 'Space Grotesk'; font-size: 1.1em;">${msg}</p>
        <button id="btn-alert-ok" class="btn-action btn-primary" style="border:none;">Ok</button>
    `;
    overlay.appendChild(box);
    document.body.appendChild(overlay);
    
    setTimeout(() => overlay.classList.add('active'), 10);
    document.getElementById('btn-alert-ok').onclick = () => {
        overlay.classList.remove('active');
        setTimeout(() => document.body.removeChild(overlay), 300);
    };
}

window.mostrarPromptAdmin = function() {
    if (isAdminLoggedIn) { window.cambiarPagina('admin'); return; }

    const overlay = document.createElement('div');
    overlay.className = 'modal-overlay';
    const box = document.createElement('div');
    box.className = 'modal-box';
    box.innerHTML = `
        <h2 style="color:var(--text-main); margin-bottom:25px; font-family: 'Space Grotesk'; font-weight: 900;">ACCESO <span class="text-gradient">ADMIN</span></h2>
        <input type="password" id="admin-pass-input" class="form-control" placeholder="Ingresa la contraseña" style="text-align:center;">
        <button id="btn-admin-submit" class="btn-action btn-primary" style="margin-bottom: 10px; border:none;">Entrar</button>
        <button id="btn-admin-cancel" class="btn-action" style="border:1px solid var(--border-color); background:transparent; color:#fff;">Cerrar</button>
    `;
    overlay.appendChild(box);
    document.body.appendChild(overlay);
    
    setTimeout(() => overlay.classList.add('active'), 10);
    document.getElementById('admin-pass-input').focus();

    const checkPass = async () => {
        const inputElement = document.getElementById('admin-pass-input');
        const pwd = inputElement.value;
        
        try {
            const res = await fetch("https://api.onyx-scripts.com/api/admin-login", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ password: pwd })
            });
            const data = await res.json();
            
            if(data.success) {
                isAdminLoggedIn = true;
                document.getElementById('link-admin').classList.add('visible');
                overlay.classList.remove('active');
                setTimeout(() => { 
                    document.body.removeChild(overlay); 
                    window.cambiarPagina('admin');
                    mostrarAlerta("Acceso concedido al panel."); 
                }, 300);
            } else {
                inputElement.value = "";
                inputElement.placeholder = "Contraseña incorrecta";
                inputElement.style.borderColor = "var(--danger)";
                setTimeout(() => { inputElement.style.borderColor = "var(--border-color)"; }, 1000);
            }
        } catch(e) {
            mostrarAlerta("Error al conectar con la base de datos.");
        }
    };
    
    document.getElementById('btn-admin-submit').onclick = checkPass;
    document.getElementById('admin-pass-input').onkeydown = (e) => { if(e.key === 'Enter') checkPass(); };
    document.getElementById('btn-admin-cancel').onclick = () => { 
        overlay.classList.remove('active'); 
        setTimeout(() => document.body.removeChild(overlay), 300); 
    };
};

document.getElementById('brand-title').addEventListener('click', () => {
    brandClickCount++;
    clearTimeout(brandClickTimer);
    if(brandClickCount === 3) { brandClickCount = 0; window.mostrarPromptAdmin(); }
    brandClickTimer = setTimeout(() => { brandClickCount = 0; }, 1000);
});

function iniciarContadorUsuarios() {
    const counterElement = document.getElementById("users-count");
    const pingDot = document.getElementById("ping-indicator");
    if (!counterElement) return;

    const myName = encodeURIComponent("OnyxWebClient");
    const myJobId = "WebPanel";

    const fetchUsers = async () => {
        try {
            const respuesta = await fetch(`https://hub.onyx-scripts.com/ping?user=${myName}&jobid=${myJobId}`, {
                method: "GET", headers: { "Astra-Auth": "OnyxHub!" }
            });
            
            if (respuesta.ok) {
                const data = await respuesta.text();
                if (data && !isNaN(data.trim())) {
                    counterElement.innerText = parseInt(data.trim()).toLocaleString();
                    pingDot.classList.remove('offline');
                }
            } else {
                counterElement.innerText = "ERR"; pingDot.classList.add('offline');
            }
        } catch (error) {
            counterElement.innerText = "OFFLINE"; pingDot.classList.add('offline');
        }
    };

    fetchUsers(); setInterval(fetchUsers, 5000);
}

window.copiarTexto = function(elementoId, boton, textoOriginal) {
    var codigo = document.getElementById(elementoId).innerText;
    const tempInput = document.createElement("textarea");
    tempInput.value = codigo;
    document.body.appendChild(tempInput); tempInput.select();
    try {
        document.execCommand("copy");
        boton.innerHTML = "¡Copiado!"; 
        setTimeout(function() { boton.innerHTML = textoOriginal; }, 2500);
    } catch (err) {}
    document.body.removeChild(tempInput);
};

function checkCooldown() {
    let lastTime = localStorage.getItem("astra_cooldown");
    if (lastTime) {
        let tp = Math.floor((Date.now() - parseInt(lastTime)) / 1000);
        let tr = 15 - tp; 
        if (tr > 0) iniciarReloj(tr); else localStorage.removeItem("astra_cooldown");
    }
}

function iniciarReloj(segundos) {
    const btn = document.getElementById("bypassBtn");
    btn.disabled = true; btn.style.opacity = "0.5";
    btn.innerText = "Cargando " + segundos + "s";
    let contador = setInterval(function() {
        segundos--;
        if (segundos > 0) { btn.innerText = "Cargando " + segundos + "s"; } 
        else {
            clearInterval(contador); btn.innerText = "Desbloquear"; btn.disabled = false; btn.style.opacity = "1";
            localStorage.removeItem("astra_cooldown");
        }
    }, 1000);
}

window.pegarPortapapeles = async function() {
    try { document.getElementById("linkInput").value = await navigator.clipboard.readText(); } 
    catch (err) { mostrarAlerta("El navegador bloqueó pegar automáticamente."); }
};

window.copiarAlPortapapeles = function(texto, boton) {
    const tempInput = document.createElement("textarea");
    tempInput.value = texto; document.body.appendChild(tempInput); tempInput.select();
    try {
        document.execCommand("copy");
        let old = boton.innerText; boton.innerText = "¡Listo!";
        setTimeout(function() { boton.innerText = old; }, 2000);
    } catch (err) { }
    document.body.removeChild(tempInput);
};

window.procesarBypass = async function() {
    const link = document.getElementById("linkInput").value;
    const resultBox = document.getElementById("result-box");
    if(!link) { mostrarAlerta("Oye, pon un link válido primero."); return; }
    localStorage.setItem("astra_cooldown", Date.now()); iniciarReloj(15); 
    resultBox.style.display = "block"; const start = performance.now();
    let crono = setInterval(() => {
        let t = ((performance.now() - start) / 1000).toFixed(1);
        resultBox.innerHTML = `<span style='color:var(--text-muted); font-family:"Fira Code";'>Saltando acortador... ${t}s</span>`;
    }, 100); 

    try {
        const response = await fetch("https://api.onyx-scripts.com/api/bypass", {
            method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ url: link })
        });
        const data = await response.json(); clearInterval(crono);
        const secs = ((performance.now() - start) / 1000).toFixed(1);

        if(data.success) {
            let r = data.url_limpia;
            if (r.startsWith("http")) {
                resultBox.innerHTML = `
                    <span style="color:var(--success); font-weight:bold;">¡Éxito! (${secs}s)</span>
                    <a href="${r}" target="_blank" class="clean-link">${r}</a>
                    <button onclick="copiarAlPortapapeles('${r}', this)" class="btn-action" style="margin-top:15px; font-size:0.85em; padding:8px;">Copiar Link</button>`;
            } else {
                resultBox.innerHTML = `
                    <span style="color:var(--success); font-weight:bold;">¡Key Lista! (${secs}s)</span>
                    <div style="margin-top:15px; padding:15px; background:var(--bg-panel); border:1px solid var(--border-color); color:var(--text-main); font-family:'Fira Code'; word-break:break-all;">${r}</div>
                    <button onclick="copiarAlPortapapeles('${r}', this)" class="btn-action" style="margin-top:15px; font-size:0.85em; padding:8px;">Copiar Key</button>`;
            }
        } else {
            resultBox.innerHTML = `<span style="color:var(--danger); font-weight:bold;">Fallo (${secs}s): ${data.error}</span>`;
        }
    } catch (error) {
        clearInterval(crono); resultBox.innerHTML = `<span style="color:var(--danger); font-weight:bold;">Error de red.</span>`;
    }
};

window.publicarScript = async function(event) {
    event.preventDefault();
    const datosScript = {
        titulo: document.getElementById('admin-titulo').value,
        tag: document.getElementById('admin-tag').value,
        juegos: document.getElementById('admin-juegos').value,
        esPrincipal: document.getElementById('admin-es-principal').checked,
        creador: document.getElementById('admin-creador').value,
        descripcion: document.getElementById('admin-desc').value,
        codigo: document.getElementById('admin-codigo').value,
        fecha: new Date().toLocaleDateString('es-ES', { day: '2-digit', month: 'long', year: 'numeric' })
    };
    try {
        const res = await fetch(VPS_API_URL, {
            method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(datosScript)
        });
        if(res.ok) {
            mostrarAlerta('Script subido a la base de datos.'); document.getElementById('form-admin').reset();
        } else { mostrarAlerta('Error en el VPS.'); }
    } catch(e) { mostrarAlerta('Sin conexión al nodo.'); }
};

// Anti-Inspect
document.addEventListener('contextmenu', event => event.preventDefault()); 
document.onkeydown = function(e) {
    if(e.keyCode == 123) return false; 
    if(e.ctrlKey && e.shiftKey && (e.keyCode == 'I'.charCodeAt(0) || e.keyCode == 'C'.charCodeAt(0) || e.keyCode == 'J'.charCodeAt(0))) return false;
    if(e.ctrlKey && e.keyCode == 'U'.charCodeAt(0)) return false; 
};
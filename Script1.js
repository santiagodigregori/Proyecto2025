let services = [
    {
        id: 1,
        title: "Reparación de tuberías",
        provider: "Juan Pérez",
        category: "plomeria",
        description: "Servicio profesional de plomería con más de 10 años de experiencia. Reparación de fugas, instalación de grifos y mantenimiento general.",
        price: 1200,
        location: "Montevideo",
        rating: 4.8,
        reviews: 25,
        icon: "🔧"
    },
    {
        id: 2,
        title: "Instalación eléctrica",
        provider: "María González",
        category: "electricidad",
        description: "Electricista matriculada con amplia experiencia en instalaciones residenciales y comerciales. Trabajos garantizados.",
        price: 1500,
        location: "Punta Carretas",
        rating: 4.9,
        reviews: 18,
        icon: "⚡"
    },
    {
        id: 3,
        title: "Limpieza de hogar",
        provider: "Limpieza Experta",
        category: "limpieza",
        description: "Servicio profesional de limpieza para hogares y oficinas. Personal capacitado y productos de calidad.",
        price: 800,
        location: "Pocitos",
        rating: 4.7,
        reviews: 42,
        icon: "🧹"
    },
    {
        id: 4,
        title: "Jardinería y paisajismo",
        provider: "Verde Natural",
        category: "jardineria",
        description: "Diseño y mantenimiento de jardines. Podas, plantación y sistemas de riego. Transformamos tu espacio exterior.",
        price: 1000,
        location: "Carrasco",
        rating: 4.6,
        reviews: 15,
        icon: "🌱"
    },
    {
        id: 5,
        title: "Muebles a medida",
        provider: "Carpintería Moderna",
        category: "carpinteria",
        description: "Diseño y fabricación de muebles personalizados. Trabajamos con maderas nobles y diseños contemporáneos.",
        price: 2500,
        location: "Cordón",
        rating: 4.9,
        reviews: 12,
        icon: "🔨"
    },
    {
        id: 6,
        title: "Pintura interior y exterior",
        provider: "Color Perfecto",
        category: "pintura",
        description: "Servicio completo de pintura para interiores y exteriores. Preparación de superficies y acabados de calidad.",
        price: 900,
        location: "Malvín",
        rating: 4.5,
        reviews: 28,
        icon: "🎨"
    }
];

let currentUser = null;
let filteredServices = [...services];


document.addEventListener('DOMContentLoaded', function () {
    renderServices(services);

    currentUser = { name: 'Usuario Demo', type: 'cliente' };
    if (currentUser && currentUser.type === 'proveedor') {
        addPublishButton();
    }
});


function openModal(modalId) {
    document.getElementById(modalId).style.display = 'block';
}

function closeModal(modalId) {
    document.getElementById(modalId).style.display = 'none';
}


window.onclick = function (event) {
    if (event.target.classList.contains('modal')) {
        event.target.style.display = 'none';
    }
}


function login(event) {
    event.preventDefault();
    const email = document.getElementById('loginEmail').value;
    const password = document.getElementById('loginPassword').value;

    currentUser = {
        name: 'Usuario Demo',
        email: email,
        type: 'cliente'
    };

    showNotification('¡Sesión iniciada correctamente!');
    closeModal('loginModal');
    updateAuthButtons();
}

function register(event) {
    event.preventDefault();
    const name = document.getElementById('registerName').value;
    const email = document.getElementById('registerEmail').value;
    const phone = document.getElementById('registerPhone').value;
    const location = document.getElementById('registerLocation').value;
    const userType = document.getElementById('userType').value;
    const password = document.getElementById('registerPassword').value;


    currentUser = {
        name: name,
        email: email,
        phone: phone,
        location: location,
        type: userType
    };

    showNotification('¡Registro exitoso! Bienvenido a ServiloYa');
    closeModal('registerModal');
    updateAuthButtons();

    if (userType === 'proveedor') {
        addPublishButton();
    }
}

function updateAuthButtons() {
    const authButtons = document.querySelector('.auth-buttons');
    if (currentUser) {
        authButtons.innerHTML = `
                    <span style="color: #0033ff; margin-right: 1rem; font-weight: 500;">Hola, ${currentUser.name}</span>
                    <a href="#" class="btn btn-secondary" onclick="logout()">Cerrar Sesión</a>
                `;
    }
}

function logout() {
    currentUser = null;
    showNotification('Sesión cerrada correctamente');
    location.reload();
}

function addPublishButton() {
    const hero = document.querySelector('.hero p');
    hero.innerHTML += '<br><button class="btn btn-primary" onclick="openModal(\'serviceModal\')" style="margin-top: 1rem;">Publicar Servicio</button>';
}


function searchServices(event) {
    event.preventDefault();
    const query = document.getElementById('searchQuery').value.toLowerCase();
    const category = document.getElementById('categoryFilter').value;
    const location = document.getElementById('locationFilter').value.toLowerCase();

    filteredServices = services.filter(service => {
        const matchesQuery = !query || service.title.toLowerCase().includes(query) ||
            service.description.toLowerCase().includes(query);
        const matchesCategory = !category || service.category === category;
        const matchesLocation = !location || service.location.toLowerCase().includes(location);

        return matchesQuery && matchesCategory && matchesLocation;
    });

    renderServices(filteredServices);


    document.getElementById('servicios').scrollIntoView({ behavior: 'smooth' });
}


function filterByCategory(category) {
    document.getElementById('categoryFilter').value = category;
    filteredServices = services.filter(service => service.category === category);
    renderServices(filteredServices);
    document.getElementById('servicios').scrollIntoView({ behavior: 'smooth' });
}


function renderServices(servicesToRender) {
    const servicesGrid = document.getElementById('servicesGrid');

    if (servicesToRender.length === 0) {
        servicesGrid.innerHTML = '<p style="text-align: center; color: white; grid-column:

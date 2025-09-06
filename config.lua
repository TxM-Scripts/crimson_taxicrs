Config = {}


Config.Keys = {
    toggleUI = 56,
    toggleMeter = 19 
}
Config.MeterPrice = {
    per100m = 50,
}

Config.Companies = {
    CRS = {
        label = "Công Ty Taxi CRS",
        price = 500000, 
        blip = {
            enable = true,
            sprite = 198,
            colour = 5,
            scale  = 0.6,
            coords = vec4(-300.05, -923.0, 31.21, 76.76),
        },
        peds = {
            {
                model    = `s_m_m_gentransport`,
                coords   = vec4(-300.05, -923.0, 31.21, 76.76),
                scenario = "WORLD_HUMAN_CLIPBOARD",
                blip     = true
            }
        },
        spawn = {
            coords = vec4(-308.05, -908.95, 30.68, 168.35)
        },
        rentVehicles = {
            { label = "Taxi CRS - Gói 1", model = "taxi", price = 500 },
            { label = "Taxi CRS - Gói 2", model = "taxi", price = 1000 },
            { label = "Taxi CRS - Gói 3", model = "taxi", price = 1200 },
        },
    },
}

Config.NpcTaxi = {
    PickLocations = {
        { label = "Bệnh viện",                              coords = vector3(278.42, -585.31, 42.31) },
        { label = "Bãi biển Vespucci",                      coords = vector3(-1402.76, -1026.88, 3.54) },
        { label = "Tòa thị chính",                          coords = vector3(-514.22, -260.49, 34.54) },
        { label = "Casino",                                 coords = vector3(922.45, 47.9, 80.11) },
        { label = "Gara 1",                                 coords = vector3(237.11, -826.29, 29.09) },
        { label = "Sân Gold",                               coords = vector3(-1377.28, 60.69, 52.7) },
        { label = "Đồn cảnh sát",                           coords = vector3(392.88, -983.42, 28.42) },
        { label = "Bến xe buýt",                            coords = vector3(432.11, -643.55, 27.72) },
        { label = "Nhà thi đấu PANIC",                      coords = vector3(-237.17, -1865.29, 27.83) },
        { label = "Bãi biển Sandy",                         coords = vector3(1651.64, 3835.83, 33.81) },
    },
    DropLocations = {
        { label = "Nhà 572",                                coords = vector3(131.64, 568.09, 182.41) },
        { label = "Nhà nghỉ Richman",                       coords = vector3(-1284.66, 296.86, 63.95) },
        { label = "Nhà Hàng Koi",                           coords = vector3(-1031.6, -1460.94, 4.06) },
        { label = "Nhà 113",                                coords = vector3(90.22, -1939.95, 19.62) },
        { label = "Sân vận động Maze Bank",                 coords = vector3(-232.08, -2047.78, 26.76) },
        { label = "Công viên Legion",                       coords = vector3(212.82, -852.1, 29.43) },
        { label = "Nhà giàu Vinewood Hills",                coords = vector3(-847.97, 457.78, 86.21) },
        { label = "Nhà máy điện",                           coords = vector3(749.41, 112.83, 77.91) },
        { label = "Nhà Nghỉ Paleto Bay",                    coords = vector3(-117.32, 6311.53, 30.5) },
        { label = "Nhà Bà Ngoại",                           coords = vector3(1709.75, 4634.21, 42.26) },
    },
}
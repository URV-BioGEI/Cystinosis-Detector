function main 

    function get_results(I)
        I_ull = imcrop(I, [100 128 712 415] ); % Tallem la imatge per a que surti només la part de l'ull
        I_gris = rgb2gray(I_ull);  % Passem a escala de grisos
        I_bin = imbinarize( I_gris, 0.35 );  % Binaritzem
        % Busquem últim píxel 
        i = size(I_bin, 2);
        flag = 1;
        while i > 1 && flag == 1 
            j = size(I_bin, 1);
            while j > 1 && flag == 1
                if I_bin(j, i) ~= 0
                    c = i;
                    r = j;
                    flag = 0;
                end
                j = j - 1;
            end
            i = i - 1;
        end

        I_processada = histeq(I_gris);  % Equalitzem
        I_erosionada = imerode(I_processada, strel('disk', 5));  % Erosionem la imatge per fer els objectes més grans
        I_bin_erosionada = imbinarize(I_erosionada, "adaptive", "sensitivity", 0.000001);  % Binaritzem deixant passar només els píxels d'objectes
        I_masked = I_gris .* uint8(I_bin_erosionada);  % Apliquem una máscara per a conservar les tonalitats de gris als llocs on hi han 1s (objectes)
        I_objects = imbinarize(I_masked, 0.1);  % Binaritzem la imatge de grisos dels objectes
        boundingboxes = regionprops(I_objects, "BoundingBox");  % Trobem els bounding boxes dels objectes de la imatge
        max_boundingbox = boundingboxes(1);  % Assignació arbitraria de bounding box maxim
        % Busquem el BoundingBox amb l'amplada més gran (el tercer camp de l'array de bounding boxes)
        for i = 1 : length(boundingboxes)
            if boundingboxes(i).BoundingBox(3) > max_boundingbox.BoundingBox(3)
                max_boundingbox = boundingboxes(i);
            end
        end
        max_boundingbox = fix(max_boundingbox.BoundingBox);  % Trunquem ja que el bounding box sempre es dona com un rectangle múltiple de 0,5 per a que sigui "contenidor"
        desfase_columnes = c - max_boundingbox(1);
        I_cornea = imcrop(I_gris, max_boundingbox);  % Obté la còrnea delimitada pel boundingbox trobat
        
        I_cornea_bin = imbinarize(I_cornea, 0.14);  % Binaritzem la cornea per a distingir cornea de fons
        % Movem píxels a la primera fila per a aplanar. Gruix aprox de la cornea: ~23 píxels a les regions més gruixudes (extrems)
        gruix_cornea = 23;
        for j = 1 : size(I_cornea, 2)  % Recorrem per columnes
            i = 1;
            x = 1;  % x es la posicio on es recolocaran els pixels de la cornea corva
            if I_cornea_bin(i, j) < 1
                while I_cornea_bin(i, j) < 1 && i < size(I_cornea, 1)  % Busquem píxels blancs
                    i = i + 1;
                end
                max_cornea = i + gruix_cornea;
                i = i - 1;
                if (x == i)  % Cas especial per quan la cornea comença a la primera linia
                    i = i + 1;
                end
                while i < max_cornea && i < size(I_cornea, 1)  % Movem els píxels blancs trobats a les primeres files
                    I_cornea(x, j) = I_cornea(i, j);
                    I_cornea(i, j) = 0;  % Ressetegem els píxels moguts
                    x = x + 1;
                    i = i + 1;
                end
            end
        end
        % Eliminem espai negre que queda per baix de la cornea
        I_flat_cornea_bin = imbinarize(I_cornea, 0.07 );
        boundingboxes = regionprops(I_flat_cornea_bin, 'BoundingBox');
        max_boundingbox = boundingboxes(1);  % Assignació arbitraria de bounding box maxim
        % Busquem el BoundingBox amb l'amplada més gran (el tercer camp de l'array de bounding boxes)
        for i = 1 : length(boundingboxes)
            if boundingboxes(i).BoundingBox(3) > max_boundingbox.BoundingBox(3)
                max_boundingbox = boundingboxes(i);
            end
        end
        I_cornea = imcrop(I_cornea, fix(max_boundingbox.BoundingBox));

        % Retallem els trossets de la cornea. 
        % Files: 250 + 300 = 550. Proporcio seccions files 250 / 550 = 0.454545... 300 / 550 = 0.545454...
        % Columnes: 4 + 4 + 4 = 12. Poporcio seccions columnes 4 / 12 = 1 / 3 = 0.333...
        props = [300 / 550, 250 / 550];
        
        % Els arguments de crop i size NO són coherents!
        % crop(Imatge, [columna, fila, amplitud, altura])
        % size(Imatge, 1) --> numfiles; size(Imatge, 2) --> numcolumnes
        seccions = cell(2, 3);
        for i = 1 : 2
            for j = 1 : 3
                seccions{i}{j} = struct('Imatge', imcrop(I_cornea, [(j - 1) * (1 / 3) * size(I_cornea, 2), (i - 1) * props(i) * size(I_cornea, 1), (1 / 3) * size(I_cornea, 2), size(I_cornea, 1) * props(i)]), 'Nombre_cristalls', 0, 'Gris_total_cristalls', 0, 'Gris_normalitzat_cristalls', 0.);
                I_bin_section = imbinarize(seccions{i}{j}.Imatge, 0.6);  % Threshold per binaritzar i detectar cristalls (calculat a ull)
                [num_pixels, tonalitats] = imhist(I_bin_section);  % Obtenim recompte de píxels blancs (cristalls) i negres (còrnea sana)
                seccions{i}{j}.Nombre_cristalls = num_pixels(2);  % Guardem a la nostra estructura de resultats
                I_cristalls_section = seccions{i}{j}.Imatge .* uint8(I_bin_section);  % Enmascarem obtenint només els grisos dels cristalls de la còrnea
                [num_pixels_gris, tonalitats_gris] = imhist(I_cristalls_section);  % Obtenim recompte de píxels segons tonalitat de gris NOMÉS als cristalls
                % Comptem el nivell de gris total dels cristalls
                nivell_gris_cristalls = 0;
                for k = 1 : size(tonalitats_gris)
                    nivell_gris_cristalls = nivell_gris_cristalls + tonalitats_gris(k) * num_pixels_gris(k);
                end
                seccions{i}{j}.Gris_total_cristalls = nivell_gris_cristalls;  % Guardem a l'estructura de resultats
                if seccions{i}{j}.Nombre_cristalls == 0
                    seccions{i}{j}.Gris_normalitzat_cristalls = 0;
                else
                    seccions{i}{j}.Gris_normalitzat_cristalls = seccions{i}{j}.Gris_total_cristalls / seccions{i}{j}.Nombre_cristalls;  
                end
                % Normalitzem: Total nivell de gris dels pixels que formen cristalls / nombre de pixels que formen cristall
            end
        end
        return 
    end  %  end of func

    I = imread( '../data/patients/PAC4/PAC4_20160707_110744_PENTACAM_R_17.BMP' );
    get_results(I)
    
    
  

end  % end of main

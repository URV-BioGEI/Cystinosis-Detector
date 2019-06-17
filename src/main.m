function main(arg1, arg2)

    function resultats = get_results(I)
        I_ull = imcrop(I, [100 128 712 415] ); % Tallem la imatge per a que surti només la part de l'ull HC per a les nostres imatges
        I_gris = rgb2gray(I_ull);  % Passem a escala de grisos
        I_processada = histeq(I_gris);  % Equalitzem
        I_erosionada = imerode(I_processada, strel('disk', 5));  % Erosionem la imatge per enmascarar la part de la cornea que no interessa
        I_bin_erosionada = imbinarize(I_erosionada, "adaptive", "sensitivity", 0.0000001);  % Binaritzem deixant passar només els píxels d'objectes. adaptive per evitar la llum i zones fosques.
        I_masked = I_gris .* uint8(I_bin_erosionada);  % Apliquem una máscara per a conservar les tonalitats de gris als llocs on hi han e1s (objectes)
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
        I_cornea = imcrop(I_gris, max_boundingbox);  % Obté la còrnea delimitada pel boundingbox trobat
        I_cornea_raw = I_cornea;  % Guardem la imatge original de la cornea
        I_cornea_bin = imbinarize(I_cornea, 0.14);  % Binaritzem la cornea per a distingir cornea de fons
        % Movem píxels a la primera fila per a aplanar. Gruix aprox de la cornea: ~23 píxels a les regions més gruixudes (extrems)
        gruix_cornea = 23;  % HC per a la majoria de corneas
        for j = 1 : size(I_cornea, 2)  % Recorrem per columnes
            i = 1;
            i_begin = 1;  % x es la posicio on es recolocaran els pixels de la cornea corva
            if I_cornea_bin(i, j) < 1
                while I_cornea_bin(i, j) < 1 && i < size(I_cornea, 1)  % Busquem píxels blancs
                    i = i + 1;
                end
                max_cornea = i + gruix_cornea;
                i = i - 1;
                if (i_begin == i)  % Cas especial per quan la cornea comença a la primera linia
                    i = i + 1;
                end
                while i < max_cornea && i < size(I_cornea, 1)  % Movem els píxels blancs trobats a les primeres files
                    I_cornea(i_begin, j) = I_cornea(i, j);
                    I_cornea(i, j) = 0;  % Ressetegem els píxels moguts
                    i_begin = i_begin + 1;
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
                % Emmaguetzem cada tros en una estructura tipus resultats(Imatge,
                % int, int, float), que está emmagatzemat en resultat seccions[2][3]
                seccions{i}{j} = struct('Imatge', imcrop(I_cornea, [(j - 1) * (1 / 3) * size(I_cornea, 2), (i - 1) * props(i) * size(I_cornea, 1), (1 / 3) * size(I_cornea, 2), size(I_cornea, 1) * props(i)]), 'Nombre_cristalls', 0, 'Gris_total_cristalls', 0, 'Gris_normalitzat_cristalls', 0.);
                I_bin_section = imbinarize(seccions{i}{j}.Imatge, 0.7);  % Threshold per binaritzar i detectar cristalls HC
                [num_pixels, ~] = imhist(I_bin_section);  % Obtenim recompte de píxels blancs (cristalls) i negres (còrnea sana)
                seccions{i}{j}.Nombre_cristalls = num_pixels(2);  % Guardem a la nostra estructura de resultats
                I_cristalls_section = seccions{i}{j}.Imatge .* uint8(I_bin_section);  % Enmascarem obtenint només els grisos dels cristalls de la còrnea
                [num_pixels_gris, tonalitats_gris] = imhist(I_cristalls_section);  % Obtenim recompte de píxels segons tonalitat de gris NOMÉS als cristalls
                % Comptem el nivell de gris total dels cristalls
                nivell_gris_cristalls = 0;
                for k = 1 : size(tonalitats_gris)
                    nivell_gris_cristalls = nivell_gris_cristalls + tonalitats_gris(k) * num_pixels_gris(k);
                end
                seccions{i}{j}.Gris_total_cristalls = nivell_gris_cristalls;  % Guardem a l'estructura de resultats
                if seccions{i}{j}.Nombre_cristalls == 0  % Per a no dividir per 0 si es dona el cas
                    seccions{i}{j}.Gris_normalitzat_cristalls = 0;
                else
                    seccions{i}{j}.Gris_normalitzat_cristalls = seccions{i}{j}.Gris_total_cristalls / seccions{i}{j}.Nombre_cristalls;  
                end
                % Normalitzem: Total nivell de gris dels pixels que formen cristalls / nombre de pixels que formen cristall
            end
        end
        resultats = cell(2);
        resultats{1} = seccions;  % Emmagatzemem la info de les seccions en la primera posicio de resultat
        
        nombre_cristalls_totals = 0;
        gris_total_cristalls = 0;
        for i = 1 : 2
            for j = 1 : 3
                nombre_cristalls_totals = nombre_cristalls_totals + seccions{i}{j}.Nombre_cristalls;
                gris_total_cristalls = gris_total_cristalls + seccions{i}{j}.Gris_total_cristalls;
            end
        end
        gris_normalitzat_total = gris_total_cristalls / nombre_cristalls_totals;
        resultats{2} = struct('Cornea_original', I_cornea_raw, 'Cornea_plana', I_cornea, 'Nombre_cristalls', nombre_cristalls_totals, 'Gris_total_cristalls', gris_total_cristalls, 'Gris_normalitzat_cristalls', gris_normalitzat_total);
    end  %  end of func
    
    % "Decora" l'output de la funció consola afegint els gràfics
    function resultats = get_results_decorator(path)
        I = imread(path);
        resultats = get_results(I);
        figure;
        for x = 1 : 2
            for y = 1 : 3
                subplot(5, 3, 6 + (y + x * 3)), imshow(resultats{1}{x}{y}.Imatge), title(sprintf("Num cristalls (píxels): %i\nNivell de gris: %i\nGris normalitzat %.3f", resultats{1}{x}{y}.Nombre_cristalls, resultats{1}{x}{y}.Gris_total_cristalls, resultats{1}{x}{y}.Gris_normalitzat_cristalls));
            end
        end
        subplot(5, 3, [1 2 3]); imshow(resultats{2}.Cornea_original); title(path);
        subplot(5, 3, [4 5 6]); imshow(resultats{2}.Cornea_plana); title(sprintf("Num cristalls totals (píxels): %i\nNivell de gris: %i\nGris normalitzat %.3f", resultats{2}.Nombre_cristalls, resultats{2}.Gris_total_cristalls, resultats{2}.Gris_normalitzat_cristalls));
        subplot(5, 3, [7 8 9]); imhist(resultats{2}.Cornea_plana); title("Histograma");
    end

    function resultats = comparar_corneas(path1, path2)
        resultats = cell(3);
        resultats{1} = get_results_decorator(path1);
        resultats{2} = get_results_decorator(path2);
        diferencia_seccions = cell(2, 3);
        for i = 1 : 2
            for j = 1 : 3
                diferencia_seccions{i}{j} = struct('Nombre_cristalls', resultats{2}{1}{i}{j}.Nombre_cristalls - resultats{1}{1}{i}{j}.Nombre_cristalls, 'Gris_total_cristalls', resultats{2}{1}{i}{j}.Gris_total_cristalls - resultats{1}{1}{i}{j}.Gris_total_cristalls, 'Gris_normalitzat_cristalls', resultats{2}{1}{i}{j}.Gris_normalitzat_cristalls - resultats{1}{1}{i}{j}.Gris_normalitzat_cristalls);
            end
        end
        resultats{3} = cell(2);
        resultats{3}{1} = diferencia_seccions;
        resultats{3}{2} = struct('Nombre_cristalls', resultats{2}{2}.Nombre_cristalls - resultats{1}{2}.Nombre_cristalls, 'Gris_total_cristalls', resultats{2}{2}.Gris_total_cristalls - resultats{1}{2}.Gris_total_cristalls, 'Gris_normalitzat_cristalls', resultats{2}{2}.Gris_normalitzat_cristalls - resultats{1}{2}.Gris_normalitzat_cristalls);
    end


    function resultats = comparar_corneas_decorator(path1, path2)
        resultats = comparar_corneas(path1, path2);
        figure;
        for i = 1 : 2
            for j = 1 : 3
                subplot(8, 3, 12 + (j + (i - 1) * 6)), imshow(resultats{1}{1}{i}{j}.Imatge), title(sprintf("Dif Num cristalls: %i\nDif nivell de gris: %i\nDif gris normalitzat %.3f", resultats{3}{1}{i}{j}.Nombre_cristalls, resultats{3}{1}{i}{j}.Gris_total_cristalls, resultats{3}{1}{i}{j}.Gris_normalitzat_cristalls)); 
                subplot(8, 3, 12 + (j + (i - 1) * 6) + 3), imshow(resultats{2}{1}{i}{j}.Imatge);
            end
        end
        subplot(8, 3, [1 2 3]), imshow(resultats{1}{2}.Cornea_original), title(path1);
        subplot(8, 3, [4 5 6]), imshow(resultats{2}{2}.Cornea_original), title(path2);
        subplot(8, 3, [7 8 9]), imshow(resultats{1}{2}.Cornea_plana);
        subplot(8, 3, [10 11 12]), imshow(resultats{2}{2}.Cornea_plana), title(sprintf("Dif Num cristalls total: %i\nDif total de gris: %i\nDif total gris normalitzat %.3f", resultats{3}{2}.Nombre_cristalls, resultats{3}{2}.Gris_total_cristalls, resultats{3}{2}.Gris_normalitzat_cristalls)); 

    end


    if exist(arg1, 'file')
        if exist(arg2, 'file')
            comparar_corneas_decorator(arg1, arg2);
        else
            get_results_decorator(arg1);
        end
    else
        "No s'ha trobat el primer fitxer"
    end
  
end  % end of main

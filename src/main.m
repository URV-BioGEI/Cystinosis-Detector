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
    desfase_columnes = c - max_boundingbox(1)
    I_cornea = imcrop(I_gris, max_boundingbox); figure, imshow(I_cornea);  % Obté la còrnea delimitada pel boundingbox trobat
    
  end  %this 'end' is needed

  I = imread( '../data/patients/PAC4/PAC4_20160707_110744_PENTACAM_R_17.BMP' );
  get_results(I)
  

end  %this 'end' is needed

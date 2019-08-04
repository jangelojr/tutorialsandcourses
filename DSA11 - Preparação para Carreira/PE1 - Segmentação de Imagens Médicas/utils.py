
# Imports
import glob
import matplotlib.patches as patches
import json
import numpy as np
from matplotlib.path import Path
import dicom
from sklearn.utils import shuffle
import cv2

def get_roi(image, contour, shape_out = 32):
    X_min, Y_min = contour[:,0].min(), contour[:,1].min()
    X_max, Y_max = contour[:,0].max(), contour[:,1].max()  
    w = X_max - X_min
    h = Y_max - Y_min
    mask_roi = np.zeros(image.shape)
    if w > h :
        mask_roi[int(Y_min - (w -h)/2):int(Y_max + (w -h)/2), int(X_min):int(X_max)] = 1.0
    else :
        mask_roi[int(Y_min):int(Y_max), int(X_min - (h-w)/2):int(X_max + (h -w)/2)] = 1.0
    return cv2.resize(mask_roi, (shape_out, shape_out), interpolation = cv2.INTER_NEAREST)

def create_dataset(image_shape=64, n_set='train', original_image_shape=256, roi_shape=32, data_path='./Data/'):
    if n_set == 'train':
        number_set = 3
        name_set = 'Training'
    elif n_set == 'test':
        number_set = 1
        name_set = 'Online'         
    series = json.load(open('series_case.json'))[n_set]
    images, images_fullsize, contours, contour_mask = [], [], [], []

    for case, serie in series.items():
        image_path_base = data_path + 'challenge_%s/%s/IM-%s' % (name_set.lower(),case, serie)
        contour_path_base = data_path + 'Sunnybrook Cardiac MR Database ContoursPart%s/\
%sDataContours/%s/contours-manual/IRCCI-expert/' % (number_set, name_set, case)
        contours_list = glob.glob(contour_path_base + '*')
        contours_list_series = [k.split('/')[7].split('-')[2] for k in contours_list]

        for c in contours_list_series:
            idx_contour = contours_list_series.index(c)
            image_path = image_path_base + '-%s.dcm' % c
            contour_path = contours_list[idx_contour]

            image_part = dicom.read_file(image_path).pixel_array  

            contour = []
            file = open(contour_path, 'r') 
            for line in file: 
                contour.append(tuple(map(float, line.split())))
            contour = np.array(contour)
            contours.append(get_roi(image_part, contour))

            x, y = np.meshgrid(np.arange(256), np.arange(256)) 
            x, y = x.flatten(), y.flatten()
            points = np.vstack((x,y)).T 
            p = Path(contour) 
            grid = p.contains_points(points)
            mask_contour = grid.reshape(256,256)
            mask_contour=mask_contour*1
            contour_mask.append(mask_contour)
            
            images.append(cv2.resize(image_part, (image_shape, image_shape)))
            images_fullsize.append(cv2.resize(image_part, (original_image_shape, original_image_shape)))
    X_fullsize = np.array(images_fullsize)
    X = np.reshape(np.array(images), [len(images), image_shape, image_shape, 1])
    Y = np.reshape(np.array(contours), [len(contours), 1, roi_shape, roi_shape])
    print('Dataset shape :', X.shape, Y.shape)
    return shuffle(X, X_fullsize, Y, contour_mask, random_state=0)

def compute_roi_pred(X_fullsize, y_pred, contour_mask, idx, roi_shape=32):
    pred = cv2.resize(y_pred[idx].reshape((roi_shape, roi_shape)), (256,256), cv2.INTER_NEAREST)
    pos_pred = np.array(np.where(pred > 0.5))
    X_min, Y_min = pos_pred[0, :].min(), pos_pred[1, :].min()
    X_max, Y_max = pos_pred[0, :].max(), pos_pred[1, :].max()  
    X_middle = X_min + (X_max - X_min) / 2
    Y_middle = Y_min + (Y_max - Y_min) / 2
    X_top = int(X_middle - 50)
    Y_top = int(Y_middle - 50)
    X_down = int(X_middle + 50)
    Y_down = int(Y_middle + 50)
    mask_roi = np.zeros((256, 256))
    mask_roi = cv2.rectangle(mask_roi, (X_top, Y_top), (X_down, Y_down), 1, -1)*255
    return X_fullsize[idx][X_top:X_down, Y_top:Y_down], mask_roi, contour_mask[idx][X_top:X_down, Y_top:Y_down]

def prediction_plot(X, model, idx=None):
    if not idx:
        idx= np.random.randint(len(X))
    contours = model.predict(X)
    contour = contours[idx].reshape((64,64))
    binary = cv2.threshold(contour, 0, 1, cv2.INTERSECT_NONE)
    return binary[1], binary[1]*X[idx].reshape(64,64), idx

def dice_metric(X, Y):
    return np.sum(X[Y==1])*2.0 / (np.sum(X) + np.sum(Y))

def conformity_coefficient(X, Y):
    if dice_metric(X,Y) !=0:
        return (3*dice_metric(X,Y)-2)/dice_metric(X,Y)

def stats_results(Y_true, Y_pred, idx=None, print_=False):
    dm_tot = np.array([dice_metric(Y_true[k].reshape((64,64)), Y_pred[k]) for k in range(len(Y_true))])
    cc_tot = np.array([conformity_coefficient(Y_true[k].reshape((64,64)), Y_pred[k]) for k in range(len(Y_true))])
    cc_tot = cc_tot[cc_tot != None]
    if idx:
        print('For image %s :\nDice Metric : %.2f\nConformity Coefficient : %.2f\n' % (
                idx, dice_metric(Y_true[idx].reshape((64,64)), Y_pred[idx]),
                conformity_coefficient(Y_true[idx].reshape((64,64)), Y_pred[idx])))

    if print_:
        print('For the full dataset :\nDice Metric : %.2f\nConformity Coefficient : %.2f' % (dm_tot.mean(),cc_tot.mean()))
    return dm_tot, cc_tot
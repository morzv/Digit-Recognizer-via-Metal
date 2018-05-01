# Digit-Recognizer-via-Metal

There is an application for course project in High School of Economics, Software Engineering department.
It is backed on the Metal framework for handwritten digits recognition. 

### Key points:
- Firstly, that application relies on CNN, which implemented by [Graph API](https://developer.apple.com/documentation/metalperformanceshaders/mpsnngraph), introduced in Metal 2.
- Secondly, for connected compoment labeling task, I am using disjoint set uniond data structure and [2 path linear algorithm.](http://aishack.in/tutorials/connected-component-labelling/)
- Finally, before putting an image to the CNN, it has to be prepared. For that purpose there is an application of four filters: Gaussian blur, Image binarization, Morphological erosion and dilation.

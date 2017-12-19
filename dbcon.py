# -*- coding: utf-8 -*-
"""
Go to the MysqlDB execute the query and creates the directories
Created on Mon Dec 18 17:22:02 2017
@author: ferreira
"""
import os
import pymysql.cursors
import pymysql

rootdir = "c:\\users\\ferreira\\documents\\test"
global intcount
intcount = 0

connection = pymysql.connect(user='root',
                             password='pass',
                             host='172.1.33.40',
                             port=3308,
                             db='net',        
                             charset='utf8mb4',
                             cursorclass=pymysql.cursors.DictCursor)        
                
sql = "SELECT * FROM  tbl_prodotto;"

def createrepodir( intprod ):    
    global intcount
    try:
        with connection.cursor() as cursor:
            cursor.execute(sql, (intprod))           
            result = cursor.fetchall()
            print( "ID prodotto: ",  intprod )
            for row in result:
                print (row["prodotto"], row["release"])
                dir01 = rootdir + "\\" + row["prodotto"].strip() + "\\" + row["release"].strip() 
                dir01 = dir01.replace(" ", "")
                dir01 = dir01.replace('"', '')
                if not os.path.exists(dir01):
                    os.makedirs(dir01)
                    print (dir01 + " created")
                    intcount = intcount + 1
                dir01 = ""
                #print(result)  
            connection.commit()    
    finally:
        print ("OK  for ID " , intprod)
        #connection.close()
#--------------------------------------------------------------------------------
prods = [1,2,6,153,5,110,135,160,177,82,174,8,7]           
for i in prods:
    createrepodir(i)    
print( "Created total of ", intcount, " directories")            
